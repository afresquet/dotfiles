{ lib, config, isLinux, ... }:
let
  cfg = config.obs-studio;
in
{
  options = {
    obs-studio.enable = lib.mkEnableOption "OBS Studio" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable { programs.obs-studio.enable = true; };
}
