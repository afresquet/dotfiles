{
  lib,
  config,
  pkgs,
  isLinux,
  ...
}:
let
  cfg = config.rofi;
in
{
  options = {
    rofi.enable = lib.mkEnableOption "rofi" // {
      default = isLinux;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.rofi.enable = true;

    home.packages = [ pkgs.rofimoji ];
  };
}
