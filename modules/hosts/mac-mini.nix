# Alvaros-Mac-mini: the headless nix-darwin server (Prometheus, Grafana, Loki)
# and its home config.
{
  inputs,
  self,
  config,
  ...
}:
let
  inherit (config.meta) keys;
in
{
  flake.darwinConfigurations.Alvaros-Mac-mini = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      (
        { config, ... }:
        {
          imports = with self.modules.darwin; [
            inputs.determinate.darwinModules.default
            brave
            rpi-imager
            auto-upgrade
            openssh
            screensharing
            tailscale
            agent-telegram
            monitoring
          ];

          networking.hostName = "Alvaros-Mac-mini";
          system.primaryUser = "afresquet";

          # Custom packages (export-grafana-dashboard, upgrade-notify) and the
          # nixpkgs patches every host shares.
          nixpkgs.overlays = [
            self.overlays.additions
            self.overlays.modifications
          ];

          users.users.${config.system.primaryUser}.openssh.authorizedKeys.keys = with keys; [
            afresquet
            alvaroDesktop
            alvaroLaptop
            alvaroPhone
            heeler
          ];

          agentTelegram = {
            secretFile = ../../secrets/agent-telegram-mac-mini.age;
          };

          # Server-mode: this Mini is headless, runs Prometheus/Grafana 24/7, and
          # should come back from anything (sleep, freeze, power loss) without the
          # user touching it.
          power = {
            restartAfterPowerFailure = true;
            restartAfterFreeze = true;
            sleep = {
              computer = "never";
              display = 30; # display can still sleep
              harddisk = "never";
            };
          };

          # Auto-login. nix-darwin sets the loginwindow preference; macOS also reads
          # /etc/kcpassword which holds an obfuscated copy of the password. The
          # kcpassword file gets created the first time you toggle "Automatic login"
          # in System Settings → Users & Groups (it needs to know the password). After
          # that the nix-darwin setting keeps the username pinned across rebuilds.
          system.defaults.loginwindow.autoLoginUser = config.system.primaryUser;

          homebrew.enable = true;

          # nix-darwin's power module covers sleep + auto-restart but not these two.
          # `pmset -a` writes to NVRAM so it sticks across reboots.
          #   womp 1     wake on magic packet (so anything on the LAN can WoL it)
          #   powernap 0 disable powernap to avoid weird half-awake states that
          #              break Tailscale connectivity
          system.activationScripts.postActivation.text = ''
            pmset -a womp 1 powernap 0
          '';

          # Determinate manages the Nix installation and owns nix.conf; our settings
          # go to /etc/nix/nix.custom.conf through its module.
          determinateNix = {
            enable = true;
            customSettings = {
              # These caches are set here for everyone because the user is not a
              # trusted Nix user (that is root in all but name), so a flake's own
              # `nixConfig` caches are ignored. Without them the Pi kernel and
              # firmware, and the harvest project's devenv shell, get compiled from
              # source.
              extra-substituters = [
                "https://nixos-raspberrypi.cachix.org"
                "https://devenv.cachix.org"
              ];
              extra-trusted-public-keys = [
                "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
                "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
              ];
              # Everything built here is signed with this key, so the Pis accept
              # packages copied from this Mac (their `trusted-public-keys` has
              # `alvaros-mac-mini-1`) without trusting a user. The file is root's,
              # mode 600, and is not in this repo.
              secret-key-files = [ "/etc/nix/signing-key.sec" ];
              # /nix is a case-sensitive APFS volume (installed with
              # `--case-sensitive`). Nix doesn't detect that and renames colliding
              # names (terminfo/l -> l~nix~case~hack~1) by default on macOS, and the
              # native Linux builder reads the store directly and sees the renamed
              # files, so NixOS initrds built here lose terminfo/l/linux.
              use-case-hack = false;
            };

            # The Linux builder VM (Pi images) defaults to 8 GiB / 1 CPU, which gets
            # the Rust compiler OOM-killed on surrealdb-core. 12 GiB of the Mac's 16.
            determinateNixd.builder = {
              memoryBytes = 12 * 1024 * 1024 * 1024;
              cpuCount = 4;
            };
          };

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 5;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";
        }
      )
    ];
  };

  flake.homeConfigurations."afresquet@Alvaros-Mac-mini" =
    inputs.home-manager.lib.homeManagerConfiguration
      {
        pkgs = import inputs.nixpkgs {
          system = "aarch64-darwin";
          overlays = [
            self.overlays.additions
            self.overlays.modifications
          ];
        };
        modules = [
          {
            imports = with self.modules.homeManager; [
              desktop
              auto-upgrade
              agent-telegram
            ];

            home.username = "afresquet";
            autoUpgrade.configuration = "afresquet@Alvaros-Mac-mini";
            agentTelegram.hostName = "Alvaros-Mac-mini";

            stylix.opacity.terminal = 0.95;

            programs.helix.settings.editor.clipboard-provider = "termcode";

            # Real copies rather than symlinks so Spotlight indexes the apps.
            targets.darwin.copyApps.enable = true;
            targets.darwin.linkApps.enable = false;
          }
        ];
      };
}
