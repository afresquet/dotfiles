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
    bluetooth = {
      enable = lib.mkEnableOption "Bluetooth" // {
        default = true;
      };

      xboxController.enable = lib.mkEnableOption "xpadneo (Xbox controller driver)" // {
        default = true;
      };
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

    hardware.xpadneo.enable = cfg.xboxController.enable;

    environment.systemPackages = [ pkgs.bluetuith ];
  };
}
