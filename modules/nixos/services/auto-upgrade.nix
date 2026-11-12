{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.autoUpgrade;

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

    allowReboot = lib.mkEnableOption "rebooting after an upgrade that changed the kernel, initrd or kernel modules";

    notify = lib.mkEnableOption "desktop notifications when the upgrade starts and finishes" // {
      default = config.desktop;
    };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = "${cfg.flake}#${config.networking.hostName}";
      inherit (cfg) operation allowReboot;
      # Two hours after the flake-update workflow starts (Saturday 04:00
      # UTC). Pinned to UTC so it stays two hours behind the cron through
      # DST. If the run hasn't committed yet, this deploys the previous
      # main, which is harmless.
      dates = "Sat 06:00 UTC";
      # Hosts that were off at that time (the laptop) catch up on next boot.
      persistent = true;
    };

    # The "-" prefix in `notify`: a failed notification must never block or
    # fail the upgrade. nixos-upgrade runs as root, so upgrade-notify hands
    # the notification to this user's session bus.
    systemd.services.nixos-upgrade = lib.mkIf cfg.notify {
      environment.NOTIFY_USER = config.username;
      serviceConfig = {
        ExecStartPre = notify "start";
        ExecStopPost = notify "stop";
      };
    };
  };
}
