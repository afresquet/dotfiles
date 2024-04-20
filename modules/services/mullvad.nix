{ lib, config, ... }: {
  options = {
    mullvad.enable = lib.mkEnableOption "Mullvad VPN";
  };

  config = {
    services.mullvad-vpn.enable = config.mullvad.enable;
  };
}
