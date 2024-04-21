{ lib, config, ... }: {
  options = {
    internet.enable = lib.mkEnableOption "Internet";
    internet.wifi.enable = lib.mkEnableOption "WiFi";
  };

  config = {
    # Define your hostname.
    networking.hostName = config.hostname;

    # Enable networking
    networking.networkmanager.enable = config.internet.enable;

    # Enables wireless support via wpa_supplicant.
    networking.wireless.enable = config.internet.wifi.enable;

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };
}
