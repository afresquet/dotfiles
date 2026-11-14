{ inputs, self, ... }:
{
  flake.modules.nixos.auto-upgrade =
    {
      lib,
      config,
      options,
      pkgs,
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
      key = "self.modules.nixos.auto-upgrade";
      imports = [ self.modules.nixos.primary-user ];

      options.autoUpgrade = {

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
          # The desktop aspect picks "boot": switching under a running graphical
          # session restarts services and can swap Hyprland out from under it.
          default = "switch";
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

        notify = lib.mkEnableOption "desktop notifications when the upgrade starts and finishes";

        telegram =
          lib.mkEnableOption "Telegram messages when the upgrade starts and finishes, through this machine's agentTelegram bot"
          // {
            # On wherever the agent-telegram aspect is: its bot sends them.
            default = options ? agentTelegram;
            defaultText = lib.literalExpression "options ? agentTelegram";
          };
      };

      config = {
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
              NOTIFY_USER = config.system.primaryUser;
            };
          })
          (lib.mkIf cfg.telegram {
            environment.TELEGRAM_ENV_FILE = config.age.secrets.agent-telegram.path;
          })
        ];
      };
    };

  flake.modules.darwin.auto-upgrade =
    {
      lib,
      config,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.autoUpgrade;

      # darwin-rebuild always switches, so /etc is the deployed configuration.
      lockFile = "dotfiles-lock";
    in
    {
      key = "self.modules.darwin.auto-upgrade";

      options.autoUpgrade = {

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
            # On wherever the agent-telegram aspect is: its bot sends them.
            default = options ? agentTelegram;
            defaultText = lib.literalExpression "options ? agentTelegram";
          };
      };

      # nix-darwin has no system.autoUpgrade; this is the launchd equivalent of
      # the nixos module above.
      config = {
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
      };
    };

  flake.modules.homeManager.auto-upgrade =
    {
      lib,
      config,
      options,
      pkgs,
      ...
    }:
    let
      cfg = config.autoUpgrade;

      name = cfg.configuration;

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
        + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          ${checkCommand} || { rc=$?; [ "$rc" -eq 1 ] && exit 0; exit "$rc"; }
        ''
        + (
          if pkgs.stdenv.hostPlatform.isDarwin then
            # launchd has no ExecStartPre/ExecStopPost, so notify around the
            # switch here, passing the result the way systemd would.
            ''
              ${lib.optionalString cfg.telegram "export TELEGRAM_ENV_FILE=${lib.escapeShellArg config.agentTelegram.envFile}"}
              ${notify "start"} || true
              rc=0
              ${switch} || rc=$?
              if [ "$rc" -eq 0 ]; then SERVICE_RESULT=success; else SERVICE_RESULT=exit-code; fi
              export SERVICE_RESULT
              ${notify "stop"} || true
              exit "$rc"
            ''
          else
            ''
              exec ${switch}
            ''
        );
      };

      switch = "${lib.getExe config.programs.home-manager.package} switch --refresh --flake ${lib.escapeShellArg "${cfg.flake}#${name}"}";

      notify =
        phase:
        "${lib.getExe pkgs.upgrade-notify} ${
          lib.escapeShellArgs [
            phase
            "Home Manager upgrade"
            (
              if pkgs.stdenv.hostPlatform.isDarwin then
                "${config.home.homeDirectory}/Library/Logs/home-manager-auto-upgrade.log"
              else
                "journalctl --user -u home-manager-auto-upgrade"
            )
          ]
        }";
    in
    {
      key = "self.modules.homeManager.auto-upgrade";

      options.autoUpgrade = {

        # The linux-desktop aspect turns them on.
        notify = lib.mkEnableOption "desktop notifications when the switch starts and finishes";

        telegram =
          lib.mkEnableOption "Telegram messages when the switch starts and finishes, through this machine's agentTelegram bot"
          // {
            # On wherever the agent-telegram aspect is: its bot sends them.
            default = options ? agentTelegram;
            defaultText = lib.literalExpression "options ? agentTelegram";
          };

        configuration = lib.mkOption {
          type = lib.types.str;
          example = "pi@Home-Server";
          description = "This configuration's name in the flake's homeConfigurations, which the timer switches to.";
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

      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion = self.homeConfigurations ? ${name};
              message = "autoUpgrade: no homeConfigurations.\"${name}\" in the flake; it switches to <username>@<hostname>.";
            }
          ];

          xdg.dataFile.${lockFile}.text = builtins.hashFile "sha256" (inputs.self + "/flake.lock");
        }

        (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
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
              Environment =
                lib.optional cfg.notify "NOTIFY_DESKTOP=1"
                ++ lib.optional cfg.telegram "TELEGRAM_ENV_FILE=${config.agentTelegram.envFile}";
            }
            # "-": a failed notification must never block or fail the upgrade.
            // lib.optionalAttrs (cfg.notify || cfg.telegram) {
              ExecStartPre = "-${notify "start"}";
              ExecStopPost = "-${notify "stop"}";
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

        (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
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
      ];
    };
}
