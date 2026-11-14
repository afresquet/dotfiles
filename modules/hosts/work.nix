# mac-afresquet: the work MacBook (nix-darwin) and its home config. The
# system config is just Determinate Nix; no auto-upgrade, it is updated by
# hand.
{ inputs, self, ... }:
{
  flake.darwinConfigurations.mac-afresquet = inputs.nix-darwin.lib.darwinSystem {
    modules = [
      {
        imports = [ inputs.determinate.darwinModules.default ];

        networking.hostName = "mac-afresquet";
        system.primaryUser = "alvaro.fresquet";

        determinateNix = {
          enable = true;
          customSettings = {
            cores = 2;
            max-jobs = 4;
            extra-substituters = [ "https://devenv.cachix.org" ];
            extra-trusted-public-keys = [
              "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
            ];
          };
        };

        system.stateVersion = 5;
        nixpkgs.hostPlatform = "aarch64-darwin";
      }
    ];
  };

  flake.homeConfigurations."alvaro.fresquet@mac-afresquet" =
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
          (
            { pkgs, ... }:
            {
              imports = with self.modules.homeManager; [
                desktop
                herdr-desktop
              ];

              home.username = "alvaro.fresquet";

              stylix.opacity.terminal = 0.95;

              # Real copies rather than symlinks so Spotlight indexes the apps.
              targets.darwin.copyApps.enable = true;
              targets.darwin.linkApps.enable = false;

              home.packages = with pkgs; [
                ruby
                cocoapods
              ];
            }
          )
        ];
      };
}
