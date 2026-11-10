{ lib, config, ... }:
let
  cfg = config.alacritty;
in
{
  options = {
    alacritty.enable = lib.mkEnableOption "Alacritty" // {
      default = config.desktop;
    };
  };

  config = lib.mkIf cfg.enable { programs.alacritty.enable = true; };
}
