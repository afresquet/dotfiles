{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.pihole;
  proxy = config.reverseProxy or { enable = false; services = { }; dnsTarget = null; };
  dnsHostEntries = lib.concatLists (
    lib.mapAttrsToList (
      _: svc: map (h: "${proxy.dnsTarget} ${h}") ([ svc.host ] ++ svc.aliases)
    ) proxy.services
  );
  shouldServeProxyDns = (proxy.enable or false) && (proxy.dnsTarget or null) != null;
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  options = {
    pihole = {
      enable = lib.mkEnableOption "Pi-hole DNS sinkhole" // {
        default = false;
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/pihole";
        description = "Directory for Pi-hole persistent state.";
      };

      upstreamDns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        description = "Upstream DNS servers Pi-hole forwards queries to.";
      };

      adminPort = lib.mkOption {
        type = lib.types.port;
        default = 8081;
        description = "Localhost port the admin UI is exposed on (proxied externally).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.pihole-webpassword.file = ../../../secrets/pihole-webpassword.age;

    # Free port 53 so the container can bind it.
    services.resolved.enable = false;

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/etc-pihole 0755 root root -"
      "d ${cfg.dataDir}/etc-dnsmasq.d 0755 root root -"
    ];

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };

    reverseProxy.services.pihole = {
      host = "pihole.home-server";
      aliases = [ "home-server" ];
      upstream = "127.0.0.1:${toString cfg.adminPort}";
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.pihole = {
        image = "pihole/pihole:latest";
        autoStart = true;
        ports = [
          "53:53/tcp"
          "53:53/udp"
          "127.0.0.1:${toString cfg.adminPort}:80/tcp"
        ];
        volumes = [
          "${cfg.dataDir}/etc-pihole:/etc/pihole"
          "${cfg.dataDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
        ];
        environment = {
          TZ = config.time.timeZone;
          FTLCONF_dns_upstreams = lib.concatStringsSep ";" cfg.upstreamDns;
          FTLCONF_dns_listeningMode = "all";
        }
        // lib.optionalAttrs shouldServeProxyDns {
          FTLCONF_dns_hosts = lib.concatStringsSep ";" dnsHostEntries;
        };
        environmentFiles = [ config.age.secrets.pihole-webpassword.path ];
        extraOptions = [ "--cap-add=NET_ADMIN" ];
      };
    };
  };
}
