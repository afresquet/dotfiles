{ lib, config, ... }:
let
  cfg = config.internet;
in
{
  options = {
    internet.enable = lib.mkEnableOption "Internet" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    # Define your hostname.
    networking.hostName = config.hostname;

    # Enable networking
    networking.networkmanager.enable = true;

    # Configure network proxy if necessary
    # networking.proxy.default = "http://user:password@proxy:port/";
    # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
  };
}
