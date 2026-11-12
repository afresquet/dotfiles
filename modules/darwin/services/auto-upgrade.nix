{ lib, config, ... }:
let
  cfg = config.autoUpgrade;
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
  };

  # nix-darwin has no system.autoUpgrade; this is the launchd equivalent of
  # the NixOS module in modules/nixos/services/auto-upgrade.nix.
  config = lib.mkIf cfg.enable {
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
          exec /run/current-system/sw/bin/darwin-rebuild switch --refresh --flake "$0"
        ''
        "${cfg.flake}#${config.networking.hostName}"
      ];
      # launchd calendar times are local only. 08:00 in Madrid is 06:00 or
      # 07:00 UTC, so at least two hours after the flake-update workflow
      # starts (Saturday 04:00 UTC), same as the NixOS hosts' 06:00 UTC.
      # A run missed while asleep fires on wake.
      StartCalendarInterval = [
        {
          Weekday = 6;
          Hour = 8;
          Minute = 0;
        }
      ];
      StandardOutPath = "/var/log/auto-upgrade.log";
      StandardErrorPath = "/var/log/auto-upgrade.log";
    };
  };
}
