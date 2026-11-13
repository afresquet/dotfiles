{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.rpi-imager;
in
{
  options = {
    rpi-imager.enable = lib.mkEnableOption "Raspberry Pi Imager" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { environment.systemPackages = [ pkgs.rpi-imager ]; };
}
