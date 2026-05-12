{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.reverseProxy;
  # Tailnet-only Caddy listener exposing /metrics. The admin endpoint
  # (port 2019) stays bound to localhost for security.
  metricsPort = 9101;
  monitoringEnabled = config.monitoring.enable or false;
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
            probePath = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = "/";
              description = ''
                Path the blackbox HTTP probe should hit (relative to host).
                Set to `null` to opt out of probing (e.g. if the service has
                no health-checkable endpoint or self-probing creates a loop).
                Override per-service when `/` doesn't return a 2xx/3xx (e.g.
                Pi-hole's UI lives under `/admin/`).
              '';
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
      # `servers { metrics }` is a global option (not per-vhost) that turns
      # on HTTP request metric collection across all servers Caddy runs.
      # Without it, only Caddy's own runtime metrics would be exposed. Only
      # set when monitoring is on — no point collecting metrics nothing
      # scrapes.
      globalConfig = lib.optionalString monitoringEnabled ''
        servers {
          metrics
        }
      '';
      virtualHosts = lib.mapAttrs' (
        _name: svc:
        lib.nameValuePair "http://${lib.concatStringsSep ", http://" ([ svc.host ] ++ svc.aliases)}" {
          extraConfig = "reverse_proxy ${svc.upstream}";
        }
      ) cfg.services
      # Dedicated tailnet-only listener for /metrics. The Caddy admin
      # endpoint (2019) stays localhost-only; this exposes just metrics.
      // lib.optionalAttrs monitoringEnabled {
        ":${toString metricsPort}".extraConfig = "metrics /metrics";
      };
    };

    # Contribute Caddy's metrics endpoint to the monitoring registry so the
    # Mac-side Prometheus scrapes it without the monitoring module needing
    # to know about Caddy.
    monitoring.exporters.caddy = lib.mkIf monitoringEnabled {
      port = metricsPort;
    };

    # Caddy resolves hostname upstreams (e.g. *.ts.net) at startup via the
    # Pi's resolver — which now points at Pi-hole. Order Caddy after the
    # Pi-hole container so that lookup doesn't race the resolver coming up.
    systemd.services.caddy = {
      after = lib.mkIf (config.pihole.enable or false) [ "podman-pihole.service" ];
      wants = lib.mkIf (config.pihole.enable or false) [ "podman-pihole.service" ];
      # Default UMask is 0077 → access logs land at 0600, so other services
      # in the `caddy` group (Promtail, etc.) can't tail them. 0027 → 0640.
      serviceConfig.UMask = "0027";
      # Existing files keep their old mode after a UMask change; reset them
      # on each start so the group-read bit becomes consistent. `find -exec`
      # silently no-ops on an empty glob but still propagates real chmod
      # failures (permission denied, etc.). The dir-exists guard tolerates
      # first-boot before LogsDirectory creates it.
      serviceConfig.ExecStartPost = "${pkgs.bash}/bin/bash -c '[ ! -d /var/log/caddy ] || ${pkgs.findutils}/bin/find /var/log/caddy -maxdepth 1 -name \"*.log\" -exec chmod g+r {} +'";
    };
  };
}
