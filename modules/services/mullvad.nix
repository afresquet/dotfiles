{ lib, config, pkgs, ... }: {
  options = {
    mullvad.enable = lib.mkEnableOption "Mullvad VPN";
  };

  config = {
    packages = lib.mkIf config.mullvad.enable [
      pkgs.mullvad-vpn
    ];

    services.mullvad-vpn.enable = config.mullvad.enable;
  };
}
