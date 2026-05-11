{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.vpn;
in
{
  imports = [ inputs.vpn-confinement.nixosModules.default ];

  options.vpn = {
    enable = lib.mkEnableOption "Mullvad WireGuard namespace (vpn-confinement)" // {
      default = false;
    };

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "wg";
      description = "Network namespace name. Service modules opting in reference this.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.mullvad-wg = {
      file = ../../../secrets/mullvad-wg.age;
      # vpn-confinement reads the file at activation as root.
    };

    vpnNamespaces.${cfg.namespace} = {
      enable = true;
      wireguardConfigFile = config.age.secrets.mullvad-wg.path;
      accessibleFrom = [
        "127.0.0.1/32"
      ];
    };
  };
}
