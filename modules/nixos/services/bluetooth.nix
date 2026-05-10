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
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        JustWorksRepairing = "always";
        Experimental = true;
      };
    };

    hardware.xpadneo.enable = true;

    environment.systemPackages = [ pkgs.bluetuith ];
  };
}
