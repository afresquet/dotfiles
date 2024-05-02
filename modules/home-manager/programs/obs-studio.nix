{ lib, config, ... }:
let
  cfg = config.obs-studio;
in
{
  options = {
    obs-studio.enable = lib.mkEnableOption "OBS Studio" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { programs.obs-studio.enable = true; };
}
