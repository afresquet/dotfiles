{ lib, config, ... }:
let
  cfg = config.mounting;
in
{
  options = {
    mounting.enable = lib.mkEnableOption "Device Mounting" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable device mounting daemon
    services.devmon.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
  };
}
