{
  lib,
  config,
  pkgs,
  inputs,
  outputs,
  isLinux,
  isDarwin,
  ...
}:
let
  cfg = config.autoUpgrade;

  name = "${config.home.username}@${config.hostname}";

  # The lock this configuration was built from, for upgrade-pending to
  # compare against main's. home-manager always activates, so the linked
  # file is the deployed configuration's.
  lockFile = "dotfiles/lock";
  deployedLock = "${config.xdg.dataHome}/${lockFile}";

  checkCommand = lib.escapeShellArgs [
    (lib.getExe pkgs.upgrade-pending)
    cfg.flake
    deployedLock
  ];

  upgradeScript = pkgs.writeShellApplication {
    name = "home-manager-auto-upgrade";
    text = ''
      # Timer and launchd environments have a bare PATH; home-manager shells
      # out to nix, which lives in the system/default profile.
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
    ''
    # On Linux the systemd unit runs the gate as ExecCondition, so a skip
    # doesn't fire the notification hooks. launchd has no such slot. Exit 1
    # is "nothing new"; anything else is a broken gate, so fail.
    + lib.optionalString isDarwin ''
      ${checkCommand} || { rc=$?; [ "$rc" -eq 1 ] && exit 0; exit "$rc"; }
    ''
    + ''
      exec ${lib.getExe config.programs.home-manager.package} switch --refresh \
        --flake ${lib.escapeShellArg "${cfg.flake}#${name}"}
    '';
  };

  # "-": a failed notification must never block or fail the upgrade.
  notify =
    phase:
    "-${lib.getExe pkgs.upgrade-notify} ${
      lib.escapeShellArgs [
        phase
        "Home Manager upgrade"
        "journalctl --user -u home-manager-auto-upgrade"
      ]
    }";
in
{
  options.autoUpgrade = {
    enable = lib.mkEnableOption "weekly home-manager switch from the published flake" // {
      default = true;
    };

    notify = lib.mkEnableOption "desktop notifications when the switch starts and finishes" // {
      # Linux only: the systemd unit carries the hooks; Macs have no
      # equivalent of ExecStopPost on a launchd agent.
      default = isLinux && config.desktop;
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "github:afresquet/dotfiles";
      description = ''
        Flake to switch from. GitHub's main rather than the local checkout:
        the flake-update workflow only commits a flake.lock once every
        configuration builds, and uncommitted local work never gets deployed
        by a timer.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = outputs.homeConfigurations ? ${name};
            message = "autoUpgrade: no homeConfigurations.\"${name}\" in the flake; it switches to <username>@<hostname>.";
          }
        ];

        xdg.dataFile.${lockFile}.text = builtins.hashFile "sha256" (inputs.self + "/flake.lock");
      }

      (lib.mkIf isLinux {
        systemd.user.services.home-manager-auto-upgrade = {
          Unit = {
            Description = "Switch home-manager to the published dotfiles flake";
            # The switch this unit runs rewrites the unit itself (a flake
            # update changes its ExecStart path), and sd-switch would then
            # stop it mid-activation, killing the switch at reloadSystemd.
            # Upstream's services.home-manager.autoUpgrade does the same.
            X-SwitchMethod = "keep-old";
          };
          Service = {
            Type = "oneshot";
            # Exit 1 skips the unit without failing it, and happens before
            # ExecStartPre, so a no-op check sends no notification.
            ExecCondition = checkCommand;
            ExecStart = lib.getExe upgradeScript;
          }
          // lib.optionalAttrs cfg.notify {
            ExecStartPre = notify "start";
            ExecStopPost = notify "stop";
          };
        };
        systemd.user.timers.home-manager-auto-upgrade = {
          Unit.Description = "Weekly home-manager switch from the published dotfiles flake";
          Timer = {
            # Every four hours, like the NixOS hosts' system.autoUpgrade: a
            # flake.lock the flake-update workflow commits late, or after a
            # failed run is fixed and rerun, deploys within hours.
            OnCalendar = "00/4:00";
            Persistent = true;
          };
          Install.WantedBy = [ "timers.target" ];
        };
      })

      (lib.mkIf isDarwin {
        home.packages = [ upgradeScript ];

        launchd.agents.home-manager-auto-upgrade = {
          enable = true;
          config = {
            # Through the profile, not the store path: home-manager boots out
            # any agent whose plist changed, which would kill the switch this
            # agent is running (launchd has no keep-old like sd-switch). A
            # stable path keeps the plist identical across generations.
            ProgramArguments = [ "${config.home.profileDirectory}/bin/home-manager-auto-upgrade" ];
            # Every four hours, like the Mac mini's system auto-upgrade.
            # Intervals missed while asleep coalesce into one run on wake.
            StartInterval = 4 * 60 * 60;
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/home-manager-auto-upgrade.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/home-manager-auto-upgrade.log";
          };
        };
      })
    ]
  );
}
