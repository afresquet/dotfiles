{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.autoUpgrade;

  # Read from the system profile rather than /etc: with operation = "boot"
  # the running system stays the old one until a reboot, and comparing
  # against it would rebuild every few hours until then.
  lockFile = "dotfiles-lock";
  deployedLock = "/nix/var/nix/profiles/system/etc/${lockFile}";

  notify =
    phase:
    "-${lib.getExe pkgs.upgrade-notify} ${
      lib.escapeShellArgs [
        phase
        "System upgrade"
        "journalctl -u nixos-upgrade"
        (if cfg.operation == "boot" then "Applies on next reboot" else "Applied")
      ]
    }";
in
{
  options.autoUpgrade = {
    enable = lib.mkEnableOption "weekly rebuild from the published flake" // {
      default = true;
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:afresquet/dotfiles";
      description = ''
        Flake to rebuild from. GitHub's main rather than the local checkout:
        the flake-update workflow only commits a flake.lock once every host
        builds, and uncommitted local work never gets deployed by a timer.
      '';
    };

    operation = lib.mkOption {
      type = lib.types.enum [
        "switch"
        "boot"
      ];
      # Switching under a running graphical session restarts services and
      # can swap Hyprland out from under it; activate on the next boot there.
      default = if config.desktop then "boot" else "switch";
    };

    dates = lib.mkOption {
      type = lib.types.str;
      # Every four hours, gated by upgrade-pending (ExecCondition below). A
      # flake.lock the flake-update workflow commits late, or after a failed
      # run is fixed and rerun, deploys within hours instead of waiting a
      # week for a fixed slot that has already passed.
      default = "00/4:00";
      description = "systemd calendar expression for when to check for a new flake.lock.";
    };

    allowReboot = lib.mkEnableOption "rebooting after an upgrade that changed the kernel, initrd or kernel modules";

    notify = lib.mkEnableOption "desktop notifications when the upgrade starts and finishes" // {
      default = config.desktop;
    };

    telegram =
      lib.mkEnableOption "Telegram messages when the upgrade starts and finishes, through this machine's agentTelegram bot"
      // {
        # `or`: hosts that pick services individually may not import it.
        default = config.agentTelegram.enable or false;
      };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = "${cfg.flake}#${config.networking.hostName}";
      inherit (cfg) operation allowReboot dates;
      # Hosts that were off (the laptop) catch up on next boot.
      persistent = true;
    };

    # The lock this configuration was built from, for upgrade-pending to
    # compare against main's.
    environment.etc.${lockFile}.text = builtins.hashFile "sha256" (inputs.self + "/flake.lock");

    systemd.services.nixos-upgrade = lib.mkMerge [
      {
        # A skip (exit 1) leaves the unit inactive rather than failed, and
        # happens before ExecStartPre, so a no-op check sends no
        # notification.
        serviceConfig.ExecCondition = lib.escapeShellArgs [
          (lib.getExe pkgs.upgrade-pending)
          cfg.flake
          deployedLock
        ];
      }

      # The "-" prefix in `notify`: a failed notification must never block
      # or fail the upgrade.
      (lib.mkIf (cfg.notify || cfg.telegram) {
        serviceConfig = {
          ExecStartPre = notify "start";
          ExecStopPost = notify "stop";
        };
      })
      # nixos-upgrade runs as root, so upgrade-notify hands the desktop
      # notification to this user's session bus.
      (lib.mkIf cfg.notify {
        environment = {
          NOTIFY_DESKTOP = "1";
          NOTIFY_USER = config.username;
        };
      })
      (lib.mkIf cfg.telegram {
        environment.TELEGRAM_ENV_FILE = config.age.secrets.agent-telegram.path;
      })
    ];

    assertions = [
      {
        assertion = cfg.telegram -> (config.agentTelegram.enable or false);
        message = "autoUpgrade.telegram sends through the agentTelegram bot; enable agentTelegram too.";
      }
    ];
  };
}
