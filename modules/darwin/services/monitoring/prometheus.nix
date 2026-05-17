{
  lib,
  config,
  pkgs,
  piConfig,
  ...
}:
let
  cfg = config.monitoring;
  port = 9090;

  # Pi declares its exporters via piConfig.monitoring.exporters; the Mac just
  # generates one scrape job per entry.
  piExporters = piConfig.monitoring.exporters or { };

  # Blackbox is a probing exporter (uses /probe with target params), not a
  # plain /metrics scrape. Pull it out so we can build its job specially.
  blackboxPort = (piExporters.blackbox or { port = 9115; }).port;
  scrapeExporters = lib.filterAttrs (n: _: n != "blackbox") piExporters;

  # HTTP probe URLs come from each Pi service's reverseProxy.services entry.
  derivedProbeUrls = lib.concatMap (
    svc: lib.optional (svc.probePath != null) "http://${svc.host}${svc.probePath}"
  ) (lib.attrValues (piConfig.reverseProxy.services or { }));
  hostsToProbe = cfg.probeUrls;

  prometheusConfig = pkgs.writeText "prometheus.yml" (builtins.toJSON {
    global = {
      scrape_interval = cfg.scrapeInterval;
      external_labels.monitor = "mac-mini";
    };

    scrape_configs =
      [
        {
          job_name = "prometheus";
          static_configs = [ { targets = [ "127.0.0.1:${toString port}" ]; } ];
        }
      ]
      # One job per /metrics-style exporter the Pi contributes. Each entry
      # carries its own port, metricsPath, optional bearer auth, and any
      # metric_relabel_configs (e.g. cAdvisor's name-from-cgroup synthesis).
      ++ lib.mapAttrsToList (name: exp: {
        job_name = name;
        metrics_path = exp.metricsPath;
        static_configs = [ { targets = [ "${cfg.targetHost}:${toString exp.port}" ]; } ];
        metric_relabel_configs = exp.metricRelabelConfigs;
      } // lib.optionalAttrs (exp.bearerTokenFile != null) {
        bearer_token_file = exp.bearerTokenFile;
      }) scrapeExporters
      # Special-case the blackbox job: it scrapes blackbox's /probe with each
      # probe URL passed as a target parameter.
      ++ lib.optional (hostsToProbe != [ ]) {
        job_name = "blackbox";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        static_configs = [ { targets = hostsToProbe; } ];
        relabel_configs = [
          { source_labels = [ "__address__" ]; target_label = "__param_target"; }
          { source_labels = [ "__param_target" ]; target_label = "instance"; }
          { target_label = "__address__"; replacement = "${cfg.targetHost}:${toString blackboxPort}"; }
        ];
      };
  });
in
{
  options.monitoring = {
    probeUrls = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = derivedProbeUrls;
      defaultText = lib.literalExpression
        "derived from piConfig.reverseProxy.services (each entry's host + probePath)";
      description = ''
        Full URLs blackbox should probe over HTTP. By default this is built
        from the Pi's reverseProxy.services attrset — each Pi service module
        contributes its own entry via probePath (set to null to skip). DNS
        resolution happens on the Pi (where blackbox runs), so any hostname
        Pi-hole serves works. Override here only to add probes for things
        outside reverseProxy.
      '';
    };

    retention = lib.mkOption {
      type = lib.types.str;
      default = "90d";
      description = "Prometheus TSDB retention.";
    };

    prometheusDataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prometheus";
    };
  };

  config = lib.mkIf cfg.enable {
    monitoring._activationDirs = [ cfg.prometheusDataDir ];

    monitoring._datasources.prometheus = pkgs.writeText "prometheus-datasource.yaml" ''
      apiVersion: 1
      # Drop any pre-existing entry first; if it was provisioned before we
      # pinned a UID, Grafana refuses to update it ("data source not found"
      # by UID, but name conflicts on insert).
      deleteDatasources:
        - { name: Prometheus, orgId: 1 }
      datasources:
        - name: Prometheus
          uid: prometheus
          type: prometheus
          access: proxy
          url: http://127.0.0.1:${toString port}
          isDefault: true
    '';

    launchd.daemons.prometheus = {
      serviceConfig = {
        Label = "com.prometheus.prometheus";
        # /bin/sh + wait4path wrapper: Determinate Nix mounts /nix from its
        # own APFS volume via a separate launchd job, so at boot xpcproxy
        # can hit ENOENT on the /nix/store binary, exit 78 instantly, and
        # land the daemon in launchd's penalty box (where KeepAlive stops
        # rescuing it). Wrapping in /bin/sh — always present pre-mount —
        # lets us block on wait4path until /nix actually appears, then exec.
        ProgramArguments = let exe = "${pkgs.prometheus}/bin/prometheus"; in [
          "/bin/sh" "-c"
          ''
            /bin/wait4path "$0"
            exec "$0" "$@"
          ''
          exe
          "--config.file=${prometheusConfig}"
          "--storage.tsdb.path=${cfg.prometheusDataDir}"
          "--storage.tsdb.retention.time=${cfg.retention}"
          "--web.listen-address=${cfg.bindAddress}:${toString port}"
          "--web.external-url=http://prometheus.home-server/"
        ];
        WorkingDirectory = cfg.prometheusDataDir;
        RunAtLoad = true;
        KeepAlive = true;
        # Retained as defense-in-depth for *genuine* crashes — the wait4path
        # wrapper handles the pre-mount race that originally pushed this
        # daemon into the penalty box.
        ThrottleInterval = 60;
        StandardOutPath = "/var/log/prometheus.log";
        StandardErrorPath = "/var/log/prometheus.err";
      };
    };
  };
}
