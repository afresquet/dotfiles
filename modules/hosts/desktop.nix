# Alvaro-Desktop: the NixOS desktop and its home config.
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
  flake.nixosConfigurations.Alvaro-Desktop = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      (
        { config, ... }:
        {
          imports = with self.modules.nixos; [
            desktop
            sunshine
            quickemu
            openlogi
            ./_desktop/hardware-configuration.nix
          ];

          networking.hostName = "Alvaro-Desktop";
          system.primaryUser = "afresquet";
          users.users.afresquet.description = "Alvaro";

          boot.initrd.kernelModules = [ "amdgpu" ];
          services.xserver.videoDrivers = [ "amdgpu" ];

          networking.interfaces.enp9s0.wakeOnLan.enable = true;

          security.polkit.extraConfig = ''
            polkit.addRule(function(action, subject) {
              if (
                subject.user == "${config.system.primaryUser}" &&
                (action.id == "org.freedesktop.login1.suspend" ||
                  action.id == "org.freedesktop.login1.suspend-multiple-sessions")
              ) {
                return polkit.Result.YES;
              }
            });
          '';

          users.users.afresquet.openssh.authorizedKeys.keys = with keys; [
            afresquet
            alvaroLaptop
            alvarosMacMini
            alvaroPhone
            heeler
          ];
        }
      )
    ];
  };

  flake.homeConfigurations."afresquet@Alvaro-Desktop" =
    inputs.home-manager.lib.homeManagerConfiguration
      {
        inherit (self.nixosConfigurations.Alvaro-Desktop) pkgs;
        modules = [
          (
            { lib, config, ... }:
            {
              imports = with self.modules.homeManager; [
                linux-desktop
                herdr-desktop
                hyprlock
              ];

              home.username = "afresquet";
              nixosAllowedUnfree = self.nixosConfigurations.Alvaro-Desktop.config.allowedUnfree;
              autoUpgrade.configuration = "afresquet@Alvaro-Desktop";

              stylix.opacity.terminal = 0.85;

              btop.rocmSupport = true;

              hyprland.monitors = [
                {
                  name = "DP-1";
                  width = 1920;
                  height = 1080;
                  refreshRate = 60.0;
                  x = 0;
                  y = 0;
                  enable = true;
                }

                {
                  name = "DP-2";
                  width = 1920;
                  height = 1080;
                  refreshRate = 60.0;
                  x = 1920;
                  y = 0;
                  enable = true;
                }

                {
                  name = "HDMI-A-1";
                  width = 3840;
                  height = 2160;
                  refreshRate = 60.0;
                  x = 3840;
                  y = 0;
                  scale = 2;
                  enable = true;
                }
              ];

              hyprland.workspaces =
                let
                  onMonitor =
                    index: names:
                    lib.genAttrs names (_: {
                      extraRules.monitor = (builtins.elemAt config.hyprland.monitors index).name;
                    });
                in
                onMonitor 0 [
                  "browser"
                  "terminal"
                  "file-manager"
                  "obsidian"
                  "steam"
                  "bambu-studio"
                  "herdr"
                ]
                // onMonitor 1 [
                  "discord"
                  "messaging"
                  "music"
                  "_1password"
                ];
            }
          )
        ];
      };
}
