{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.bluetooth;
in
{
  options = {
    bluetooth.enable = lib.mkEnableOption "Bluetooth" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable bluetooth
    hardware.bluetooth.enable = true;

    environment.systemPackages = [ pkgs.bluetuith ];
  };
}
