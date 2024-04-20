{ lib, config, ... }: {
  options = {
    bluetooth.enable = lib.mkEnableOption "Bluetooth";
  };

  config = {
    bluetooth.enable = lib.mkDefault true;

    # Enable bluetooth
    hardware.bluetooth = {
      enable = config.bluetooth.enable;
      powerOnBoot = config.bluetooth.enable;
    };
  };
}
