{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.monitoring;
  port = 3100;

  lokiConfig = pkgs.writeText "loki.yml" (builtins.toJSON {
    auth_enabled = false;
    server = {
      http_listen_address = cfg.bindAddress;
      http_listen_port = port;
      # gRPC listener stays localhost — only Loki's internal components use
      # it on a single-binary deploy.
      grpc_listen_address = "127.0.0.1";
      grpc_listen_port = 9096;
    };
    common = {
      path_prefix = cfg.lokiDataDir;
      storage.filesystem = {
        chunks_directory = "${cfg.lokiDataDir}/chunks";
        rules_directory = "${cfg.lokiDataDir}/rules";
      };
      replication_factor = 1;
      ring.kvstore.store = "inmemory";
      # Force every internal component (frontend, scheduler, querier, ring,
      # compactor) to advertise/dial 127.0.0.1. Without this Loki picks the
      # host's primary LAN address and the scheduler tries to call back to
      # an interface we never bound gRPC on → "connection refused" tail.
      instance_addr = "127.0.0.1";
    };
    schema_config.configs = [{
      from = "2024-01-01";
      store = "tsdb";
      object_store = "filesystem";
      schema = "v13";
      index = { prefix = "index_"; period = "24h"; };
    }];
    limits_config = {
      retention_period = cfg.lokiRetention;
      reject_old_samples = true;
      reject_old_samples_max_age = "168h";
      allow_structured_metadata = true;
      # Default ingestion limits (4 MB/s rate, 6 MB burst) make Promtail
      # 429 constantly when backfilling existing log files (e.g. the ~50 MB
      # of historical Caddy access logs at first start). Bumped for a
      # single-tenant homelab.
      ingestion_rate_mb = 16;
      ingestion_burst_size_mb = 32;
    };
    compactor = {
      working_directory = "${cfg.lokiDataDir}/compactor";
      compaction_interval = "10m";
      retention_enabled = true;
      retention_delete_delay = "2h";
      delete_request_store = "filesystem";
    };
    analytics.reporting_enabled = false;
  });
in
{
  options.monitoring = {
    lokiDataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/loki";
    };

    lokiRetention = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = "Loki log retention. 720h = 30 days. Bump for longer history (more disk).";
    };
  };

  config = lib.mkIf cfg.enable {
    monitoring._activationDirs = [
      cfg.lokiDataDir
      "${cfg.lokiDataDir}/chunks"
      "${cfg.lokiDataDir}/rules"
      "${cfg.lokiDataDir}/compactor"
    ];

    monitoring._datasources.loki = pkgs.writeText "loki-datasource.yaml" ''
      apiVersion: 1
      deleteDatasources:
        - { name: Loki, orgId: 1 }
      datasources:
        - name: Loki
          uid: loki
          type: loki
          access: proxy
          url: http://127.0.0.1:${toString port}
    '';

    launchd.daemons.loki = {
      serviceConfig = {
        Label = "com.grafana.loki";
        # See wait4path rationale on the prometheus daemon.
        ProgramArguments = let exe = "${pkgs.grafana-loki}/bin/loki"; in [
          "/bin/sh" "-c"
          ''
            /bin/wait4path "$0"
            exec "$0" "$@"
          ''
          exe
          "-config.file=${lokiConfig}"
        ];
        WorkingDirectory = cfg.lokiDataDir;
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 60;
        StandardOutPath = "/var/log/loki.log";
        StandardErrorPath = "/var/log/loki.err";
      };
    };
  };
}
