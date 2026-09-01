{
  lib,
  config,
  ...
}:
let
  cfg = config.monitoring;

  port = 9080;
  lokiPort = 3100;
in
{
  config = lib.mkIf (cfg.enable && cfg.serverHost != null) {
    services.alloy = {
      enable = true;
      extraFlags = [
        "--server.http.listen-addr=0.0.0.0:${toString port}"
        "--disable-reporting"
      ];
    };

    systemd.services.alloy.serviceConfig.SupplementaryGroups =
      lib.mkAfter (lib.optional (config.services.caddy.enable or false) "caddy");

    environment.etc."alloy/config.alloy".text = ''
      loki.relabel "journal" {
        forward_to = []

        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }

        rule {
          source_labels = ["__journal_priority_keyword"]
          target_label  = "level"
        }
      }

      loki.process "journal" {
        forward_to = [loki.write.mac.receiver]

        stage.drop {
          expression          = "SQLite error.*SHOW server_version"
          drop_counter_reason = "sqlite_probe_noise"
        }

        stage.drop {
          expression          = "tail: /var/log/pihole/FTL\\.log: file truncated"
          drop_counter_reason = "pihole_log_rotation"
        }
      }

      loki.source.journal "systemd" {
        max_age       = "12h"
        relabel_rules = loki.relabel.journal.rules
        labels        = {
          job  = "systemd-journal",
          host = "${config.hostname}",
        }
        forward_to = [loki.process.journal.receiver]
      }

      local.file_match "caddy" {
        path_targets = [{
          __path__ = "/var/log/caddy/*.log",
          job      = "caddy",
          host     = "${config.hostname}",
        }]
      }

      loki.source.file "caddy" {
        targets    = local.file_match.caddy.targets
        forward_to = [loki.write.mac.receiver]
      }

      loki.write "mac" {
        endpoint {
          url = "http://${cfg.serverHost}:${toString lokiPort}/loki/api/v1/push"
        }
      }
    '';

    monitoring.exporters.alloy = { inherit port; };

    monitoring.dashboards.logs = {
      json = ./dashboards/logs.json;
    };
  };
}
