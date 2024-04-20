{ lib, config, ... }: {
  options = {
    mounting.enable = lib.mkEnableOption "Device Mounting";
  };

  config =
    let
      inherit (config.mounting) enable;
    in
    {
      mounting.enable = lib.mkDefault true;

      # Enable device mounting daemon
      services.devmon.enable = enable;
      services.gvfs.enable = enable;
      services.udisks2.enable = enable;
    };
}
