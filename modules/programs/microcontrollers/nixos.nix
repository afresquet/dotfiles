{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.microcontrollers;
in
{
  options = {
    microcontrollers.enable = lib.mkEnableOption "Microcontrollers" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ arduino-ide ];

    services.udev.packages = with pkgs; [
      platformio-core
      openocd
    ];
  };
}
