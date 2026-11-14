{ lib, config, ... }:
let
  cfg = config.network;
in
{
  options = {
    network.enable = lib.mkEnableOption "hostname and NetworkManager" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = config.hostname;
    networking.networkmanager.enable = true;
  };
}
