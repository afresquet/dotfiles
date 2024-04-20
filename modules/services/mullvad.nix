{ lib, config, ... }: {
  options = {
    mullvad.enable = lib.mkEnableOption "Mullvad VPN";
  };

  config = {
    mullvad.enable = lib.mkDefault true;

    services.mullvad-vpn.enable = config.mullvad.enable;
  };
}
