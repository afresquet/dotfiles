{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.autoUpgrade;

  # darwin-rebuild always switches, so /etc is the deployed configuration.
  lockFile = "dotfiles-lock";
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

    telegram =
      lib.mkEnableOption "Telegram messages when the upgrade starts and finishes, through this machine's agentTelegram bot"
      // {
        # `or`: hosts that pick services individually may not import it.
        default = config.agentTelegram.enable or false;
      };
  };

  # nix-darwin has no system.autoUpgrade; this is the launchd equivalent of
  # the NixOS module in modules/nixos/services/auto-upgrade.nix.
  config = lib.mkIf cfg.enable {
    # The lock this configuration was built from, for upgrade-pending to
    # compare against main's.
    environment.etc.${lockFile}.text = builtins.hashFile "sha256" (inputs.self + "/flake.lock");

    # Run through /run/current-system rather than by store path: activation
    # reloads a daemon whose plist changed, which would kill the upgrade
    # mid-switch. With no store paths in it, the plist stays the same.
    environment.systemPackages = [
      pkgs.upgrade-pending
      pkgs.upgrade-notify
    ];

    launchd.daemons.auto-upgrade.serviceConfig = {
      Label = "org.nixos.auto-upgrade";
      # wait4path: /nix is mounted by a separate launchd job and may not be
      # there yet if a missed run fires right at boot. darwin-rebuild from
      # the current system sets its own PATH, which includes Determinate's
      # nix in /nix/var/nix/profiles/default/bin.
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ''
          /bin/wait4path /nix/store
          bin=/run/current-system/sw/bin
          # 1 is "nothing new"; anything else is a broken gate, so fail.
          "$bin/upgrade-pending" "$1" /etc/${lockFile} || { rc=$?; [ "$rc" -eq 1 ] && exit 0; exit "$rc"; }
          # Notifications never fail the upgrade; launchd has no
          # ExecStopPost, so the result is passed the way systemd would.
          notify() { "$bin/upgrade-notify" "$1" "System upgrade" /var/log/auto-upgrade.log Applied || true; }
          notify start
          "$bin/darwin-rebuild" switch --refresh --flake "$0" && rc=0 || rc=$?
          if [ "$rc" -eq 0 ]; then SERVICE_RESULT=success; else SERVICE_RESULT=exit-code; fi
          export SERVICE_RESULT
          notify stop
          exit "$rc"
        ''
        "${cfg.flake}#${config.networking.hostName}"
        cfg.flake
      ];
      EnvironmentVariables = lib.mkIf cfg.telegram {
        TELEGRAM_ENV_FILE = config.age.secrets.agent-telegram.path;
      };
      # Every four hours, gated by upgrade-pending like the NixOS hosts: a
      # flake.lock the flake-update workflow commits late, or after a failed
      # run is fixed and rerun, deploys within hours instead of a week later.
      # Intervals missed while asleep coalesce into one run on wake.
      StartInterval = 4 * 60 * 60;
      StandardOutPath = "/var/log/auto-upgrade.log";
      StandardErrorPath = "/var/log/auto-upgrade.log";
    };

    assertions = [
      {
        assertion = cfg.telegram -> (config.agentTelegram.enable or false);
        message = "autoUpgrade.telegram sends through the agentTelegram bot; enable agentTelegram too.";
      }
    ];
  };
}
