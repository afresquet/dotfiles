{
  lib,
  config,
  ...
}:
let
  cfg = config.rpi-imager;
in
{
  options = {
    rpi-imager.enable = lib.mkEnableOption "Raspberry Pi Imager (Homebrew cask)" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { homebrew.casks = [ "raspberry-pi-imager" ]; };
}
