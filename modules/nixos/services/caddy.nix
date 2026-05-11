{
  lib,
  config,
  ...
}:
let
  cfg = config.reverseProxy;
in
{
  options.reverseProxy = {
    enable = lib.mkEnableOption "Caddy reverse proxy" // {
      default = false;
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = "Interface on which port 80 is firewall-allowed.";
    };

    dnsTarget = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        IP that all proxied hostnames should resolve to. If set, downstream
        DNS modules (e.g. pihole) can read this to auto-create local A records.
      '';
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "Hostname the service responds to (Host header).";
            };
            upstream = lib.mkOption {
              type = lib.types.str;
              description = "Upstream address:port caddy proxies to.";
            };
            aliases = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Extra hostnames that should resolve to this service.";
            };
          };
        }
      );
      default = { };
      description = "Reverse-proxied services keyed by an internal name.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = [ 80 ];

    services.caddy = {
      enable = true;
      virtualHosts = lib.mapAttrs' (
        _name: svc:
        lib.nameValuePair "http://${lib.concatStringsSep ", http://" ([ svc.host ] ++ svc.aliases)}" {
          extraConfig = "reverse_proxy ${svc.upstream}";
        }
      ) cfg.services;
    };
  };
}
