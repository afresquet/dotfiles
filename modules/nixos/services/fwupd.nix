{ lib, config, ... }:
let
  cfg = config.fwupd;
in
{
  options = {
    fwupd.enable = lib.mkEnableOption "fwupd" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Firmware Update Manager
    services.fwupd.enable = true;
  };
}
