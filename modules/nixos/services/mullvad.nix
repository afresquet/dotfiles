{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.mullvad;
in
{
  options = {
    mullvad.enable = lib.mkEnableOption "Mullvad VPN" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.mullvad-vpn ];

    services.mullvad-vpn.enable = true;
  };
}
