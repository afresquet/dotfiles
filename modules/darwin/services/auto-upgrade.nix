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
  };

  # nix-darwin has no system.autoUpgrade; this is the launchd equivalent of
  # the NixOS module in modules/nixos/services/auto-upgrade.nix.
  config = lib.mkIf cfg.enable {
    # The lock this configuration was built from, for upgrade-pending to
    # compare against main's.
    environment.etc.${lockFile}.text = builtins.hashFile "sha256" (inputs.self + "/flake.lock");

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
          # 1 is "nothing new"; anything else is a broken gate, so fail.
          "$1" "$2" /etc/${lockFile} || { rc=$?; [ "$rc" -eq 1 ] && exit 0; exit "$rc"; }
          exec /run/current-system/sw/bin/darwin-rebuild switch --refresh --flake "$0"
        ''
        "${cfg.flake}#${config.networking.hostName}"
        (lib.getExe pkgs.upgrade-pending)
        cfg.flake
      ];
      # Every four hours, gated by upgrade-pending like the NixOS hosts: a
      # flake.lock the flake-update workflow commits late, or after a failed
      # run is fixed and rerun, deploys within hours instead of a week later.
      # Intervals missed while asleep coalesce into one run on wake.
      StartInterval = 4 * 60 * 60;
      StandardOutPath = "/var/log/auto-upgrade.log";
      StandardErrorPath = "/var/log/auto-upgrade.log";
    };
  };
}
