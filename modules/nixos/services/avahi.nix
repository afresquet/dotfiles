{
  lib,
  config,
  options,
  inputs,
  ...
}:
let
  cfg = config.avahi;
  raspberrypiRelease = inputs.nixos-raspberrypi.inputs.nixpkgs.lib.trivial.release;
in
{
  options.avahi.enable = lib.mkEnableOption "Avahi mDNS/DNS-SD" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !lib.versionAtLeast raspberrypiRelease "26.11";
        message = "avahi: nixos-raspberrypi now pins nixpkgs ${raspberrypiRelease}, which has services.avahi.settings; drop the legacy publish fallback in modules/nixos/services/avahi.nix";
      }
    ];

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
      openFirewall = true;
    }
    // (
      if options.services.avahi ? settings then
        {
          settings.publish = {
            disable-publishing = false;
            publish-addresses = true;
            publish-workstation = true;
          };
        }
      else
        {
          publish = {
            enable = true;
            addresses = true;
            workstation = true;
          };
        }
    );
  };
}
