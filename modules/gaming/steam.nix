{ self, ... }:
{
  flake.modules.nixos.steam =
    {
      config,
      pkgs,
      ...
    }:
    {
      imports = [
        self.modules.nixos.primary-user
        self.modules.nixos.allowed-unfree
      ];

      config = {
        programs.steam = {
          enable = true;
          remotePlay.openFirewall = true;
          dedicatedServer.openFirewall = true;
          # Wrapper for resolution and upscailing problems
          # gamescope %command%
          gamescopeSession.enable = true;
        };

        # Wrapper for optimizations
        # gamemoderun %command%
        programs.gamemode.enable = true;

        environment.systemPackages = with pkgs; [
          # Wrapper for HUD
          # mangohud %command%
          mangohud
          protonup-ng
        ];

        environment.sessionVariables = {
          STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${
            config.users.users.${config.system.primaryUser}.home
          }/.steam/root/compatibilitytools.d";
        };

        allowedUnfree = [
          "steam"
          "steam-run"
          "steam-unwrapped"
        ];
      };
    };
}
