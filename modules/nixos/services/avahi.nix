{ lib, config, ... }:
let
  cfg = config.avahi;
in
{
  options.avahi.enable = lib.mkEnableOption "Avahi mDNS/DNS-SD" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
      publish = {
        enable = true;
        addresses = true;
        workstation = true;
      };
    };
  };
}
