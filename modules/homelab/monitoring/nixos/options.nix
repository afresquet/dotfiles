# Option declarations only. Service modules that contribute exporters or
# dashboards import this file (not default.nix) so there is no import cycle
# between them and the monitoring implementation.
{ lib, ... }:
{
  options.monitoring = {
    enable = lib.mkEnableOption "Prometheus exporters and Alloy log shipping" // {
      default = false;
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = "Interface on which exporter ports are firewall-allowed.";
    };

    serverHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "100.64.0.5";
      description = ''
        Tailnet host (IP or MagicDNS name) running Prometheus + Grafana + Loki.
        When set, Caddy proxies grafana.home-server and prometheus.home-server
        to it, a Grafana tile shows up on the dashboard, and Alloy ships logs
        to Loki.
      '';
    };

    # ─── Cross-module contribution points ───
    # Service modules contribute their own exporter and dashboard entries
    # here. The Mac's monitoring module reads `piConfig.monitoring.{exporters,
    # dashboards}` to drive Prometheus and Grafana provisioning, so adding a
    # new monitored service is purely a one-module change on the Pi side.

    exporters = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.port;
              description = "Port the exporter listens on (bound to all interfaces).";
            };
            metricsPath = lib.mkOption {
              type = lib.types.str;
              default = "/metrics";
              description = "HTTP path Prometheus should scrape.";
            };
            metricRelabelConfigs = lib.mkOption {
              type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
              default = [ ];
              description = "Prometheus metric_relabel_configs for this scrape job.";
            };
            bearerTokenFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Path on the SCRAPING host (the Mac) containing a raw bearer
                token for `Authorization: Bearer …`. Use this when the
                exporter requires auth (e.g. Home Assistant's
                `/api/prometheus`). The Pi declares the expected path; the
                Mac's agenix is responsible for decrypting the secret to it.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Prometheus exporters this host runs. Each entry becomes a scrape job
        on the upstream Prometheus instance and an opened firewall port on
        `monitoring.interface`. Service modules contribute their own.
      '';
    };

    dashboards = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = ''
                Direct download URL for the dashboard JSON. If null, the URL
                is built from `id` + `revision` against grafana.com. Use this
                when the dashboard isn't on grafana.com (e.g. shipped from a
                project's own repo).
              '';
            };
            json = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              description = ''
                Local path to a dashboard JSON (e.g. shipped under
                `monitoring/dashboards/`). Bypasses the url/id/revision/hash
                flow entirely.
              '';
            };
            id = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "grafana.com dashboard ID. Ignored if `url` or `json` is set.";
            };
            revision = lib.mkOption {
              type = lib.types.nullOr lib.types.int;
              default = null;
              description = "grafana.com revision number. Ignored if `url` or `json` is set.";
            };
            hash = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "SRI hash of the downloaded dashboard JSON. Required for `url`/`id`+`revision`.";
            };
            extraFilter = lib.mkOption {
              type = lib.types.str;
              default = ".";
              description = ''
                Additional jq filter applied after the global datasource/UID
                normalization. Use this to fix per-dashboard quirks (unit
                mismatches, hardcoded label filters, etc.) without leaking
                those concerns into the central monitoring module. Default
                is `.` (pass-through).
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Grafana dashboards the upstream Grafana should provision. Service
        modules contribute their own. Sourced from grafana.com via `id` +
        `revision`, or from any direct `url`, or from a local `json` path.
      '';
    };
  };
}
