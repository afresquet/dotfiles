{
  lib,
  config,
  ...
}:
let
  cfg = config.monitoring;

  # Promtail's own /metrics + admin endpoint. Loki listens on 3100 on the Mac.
  port = 9080;
  lokiPort = 3100;
in
{
  config = lib.mkIf (cfg.enable && cfg.serverHost != null) {
    # Promtail's hardened systemd unit bind-mounts /var/lib/promtail into
    # its namespace (for the positions cursor file). Without the dir, the
    # NAMESPACE step fails before the binary even runs.
    systemd.tmpfiles.rules = [ "d /var/lib/promtail 0700 promtail promtail -" ];

    # Caddy's access logs are owned `caddy:caddy` with mode 0640 — promtail
    # can't read them otherwise. Group-add lets us tail without loosening
    # the file perms or running promtail as caddy.
    users.users.promtail.extraGroups = lib.mkIf (config.services.caddy.enable or false) [ "caddy" ];

    # Tails systemd journal (covers every native service and every podman
    # container, since `podman-X.service`'s stdout/stderr go to journald) and
    # Caddy's file-based access logs. Ships everything to Loki on the Mac.
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_address = "0.0.0.0";
          http_listen_port = port;
          # gRPC unused; turn off to free its random port.
          grpc_listen_port = 0;
        };
        positions.filename = "/var/lib/promtail/positions.yaml";
        clients = [
          { url = "http://${cfg.serverHost}:${toString lokiPort}/loki/api/v1/push"; }
        ];
        scrape_configs = [
          {
            # systemd-journal: every unit's stdout/stderr, plus kernel msgs.
            job_name = "journal";
            journal = {
              max_age = "12h";
              labels = { job = "systemd-journal"; host = config.hostname; };
            };
            relabel_configs = [
              { source_labels = [ "__journal__systemd_unit" ]; target_label = "unit"; }
              { source_labels = [ "__journal_priority_keyword" ]; target_label = "level"; }
            ];
            pipeline_stages = [
              # Drop known-harmless noise that fires every scrape interval and
              # would otherwise dominate the log stream:
              #   - Sonarr/Radarr probe for a Postgres backend on each API
              #     call; SQLite errors out on the `SHOW server_version`
              #     they issue but the apps proceed normally.
              #   - Pi-hole's container entrypoint tails FTL.log and emits
              #     a "file truncated" line when pihole-FTL rotates at
              #     midnight.
              { drop = { expression = ''SQLite error.*SHOW server_version''; }; }
              { drop = { expression = ''tail: /var/log/pihole/FTL\.log: file truncated''; }; }
            ];
          }
          {
            # Caddy's per-vhost access logs (one file per host).
            job_name = "caddy";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                job = "caddy";
                host = config.hostname;
                __path__ = "/var/log/caddy/*.log";
              };
            }];
          }
        ];
      };
    };

    # Promtail also exposes /metrics — let the Mac's Prometheus scrape it
    # for shipping rate, error counts, etc.
    monitoring.exporters.promtail = { inherit port; };

    # Logs overview dashboard (LogQL queries against Loki). Variable-driven:
    # pick a unit (or "All"), optionally type a regex into the search box.
    monitoring.dashboards.logs = {
      json = ./dashboards/logs.json;
    };
  };
}
