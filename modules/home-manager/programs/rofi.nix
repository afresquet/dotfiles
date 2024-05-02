{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.rofi;
in
{
  options = {
    rofi.enable = lib.mkEnableOption "rofi" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi-wayland;
    };
  };
}
