{ lib, config, ... }: {
  options = {
    bluetooth.enable = lib.mkEnableOption "Bluetooth";
  };

  config = {
    # Enable bluetooth
    hardware.bluetooth = {
      enable = config.bluetooth.enable;
      powerOnBoot = config.bluetooth.enable;
    };
  };
}
