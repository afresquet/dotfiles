{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.steam;
in
{
  options = {
    steam.enable = lib.mkEnableOption "Steam" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
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
      protonup
    ];

    environment.sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/${config.username}/.steam/root/compatibilitytools.d";
    };

    allowedUnfree = [
      "steam"
      "steam-original"
      "steam-run"
      "steam-unwrapped"
    ];
  };
}
