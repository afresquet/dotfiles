{
  lib,
  config,
  pkgs,
  outputs,
  isLinux,
  isDarwin,
  ...
}:
let
  cfg = config.autoUpgrade;

  name = "${config.home.username}@${config.hostname}";

  upgradeScript = pkgs.writeShellApplication {
    name = "home-manager-auto-upgrade";
    text = ''
      # Timer and launchd environments have a bare PATH; home-manager shells
      # out to nix, which lives in the system/default profile.
      export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
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
            # Same slot as the NixOS hosts' system.autoUpgrade: two hours
            # after the flake-update workflow starts (Saturday 04:00 UTC).
            OnCalendar = "Sat 06:00 UTC";
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
            # launchd calendar times are local only; 08:00 in Madrid is at
            # least two hours after the workflow's 04:00 UTC start, matching
            # the Mac mini's system auto-upgrade. Missed runs fire on wake.
            StartCalendarInterval = [
              {
                Weekday = 6;
                Hour = 8;
                Minute = 0;
              }
            ];
            StandardOutPath = "${config.home.homeDirectory}/Library/Logs/home-manager-auto-upgrade.log";
            StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/home-manager-auto-upgrade.log";
          };
        };
      })
    ]
  );
}
