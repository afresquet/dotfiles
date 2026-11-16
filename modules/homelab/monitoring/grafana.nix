{
  flake.modules.darwin.monitoring =
    {
      lib,
      config,
      pkgs,
      piConfig,
      ...
    }:
    let
      cfg = config.monitoring;
      port = 3000;

      # Pi service modules contribute Grafana dashboards via
      # piConfig.monitoring.dashboards. Each entry is fetched (or read locally
      # from a `json = ./...` file), normalized, and placed in a linkFarm that
      # Grafana scans on startup.
      piDashboards = piConfig.monitoring.dashboards or { };

      # jq filter that:
      #   - maps `${DS_PROMETHEUS}` / `${DS_LOKI}` placeholders to our pinned UIDs
      #   - normalizes a `datasource` field that's a bare object (no uid/type) to
      #     prometheus — but leaves any datasource that already names a uid/type
      #     alone, so hand-written Loki dashboards survive
      #   - strips `__inputs` so provisioning doesn't choke on prompts
      fixDashboard = ''
        def mapPlaceholder:
          if test("LOKI") then "loki" else "prometheus" end;

        walk(
          if type == "string" and test("^\\$\\{DS_") then
            mapPlaceholder
          elif type == "object" and has("datasource") then
            .datasource |= (
              if type == "string" and test("^\\$\\{DS_") then mapPlaceholder
              elif type == "object" and ((has("uid") and has("type")) | not) then
                . + { uid: "prometheus", type: "prometheus" }
              else . end
            )
          else . end
        ) | del(.__inputs)
      '';

      # grafana.com revisions, kept current by `nix run .#update-pins`.
      grafanaCom = lib.importJSON ./dashboards/grafana-com.json;

      mkDashboard =
        {
          id,
          json,
          name,
          extraFilter,
        }:
        let
          pin =
            grafanaCom.${toString id}
            or (throw "dashboard ${name}: grafana.com dashboard ${toString id} isn't pinned, run `nix run .#update-pins`");
          raw =
            if json != null then
              json
            else
              pkgs.fetchurl {
                url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString pin.revision}/download";
                inherit (pin) hash;
              };
        in
        pkgs.runCommand "grafana-dashboard-${name}.json"
          {
            nativeBuildInputs = [ pkgs.jq ];
          }
          ''
            # Two-phase: render to a tmp file, then sanity-check the result is a
            # JSON dashboard object before committing to $out. Catches extraFilter
            # mistakes (returning null, an array, dropping the whole document) at
            # build time instead of at Grafana load time, where they'd just be a
            # silent "dashboard not found".
            jq '${fixDashboard} | ${extraFilter}' ${raw} > dashboard.json
            jq -e 'type == "object" and has("title") and (has("panels") or has("rows"))' \
              dashboard.json > /dev/null \
              || { echo "dashboard ${name}: post-filter output is not a Grafana dashboard object" >&2; exit 1; }
            mv dashboard.json $out
          '';

      dashboards = pkgs.linkFarm "grafana-dashboards" (
        lib.mapAttrsToList (name: d: {
          name = "${name}.json";
          path = mkDashboard {
            inherit (d) id json extraFilter;
            inherit name;
          };
        }) piDashboards
      );

      # The Pi's alerts, as one rule group. Each query is turned into a series
      # of 1s with the same labels (`* 0 + 1`), so the threshold just checks a
      # series exists, whatever value the expression returns (`up == 0` is 0),
      # and each series alerts separately. No data is the healthy state.
      alertRules = pkgs.writeText "alert-rules.yaml" (
        builtins.toJSON {
          apiVersion = 1;
          groups = [
            {
              orgId = 1;
              name = "home-server";
              folder = "Home Server";
              interval = "1m";
              rules = lib.mapAttrsToList (uid: a: {
                inherit uid;
                inherit (a) title for;
                condition = "B";
                data = [
                  {
                    refId = "A";
                    relativeTimeRange = {
                      from = 600;
                      to = 0;
                    };
                    datasourceUid = "prometheus";
                    model = {
                      refId = "A";
                      expr = "(${a.expr}) * 0 + 1";
                      instant = true;
                    };
                  }
                  {
                    refId = "B";
                    datasourceUid = "__expr__";
                    model = {
                      refId = "B";
                      type = "threshold";
                      expression = "A";
                      conditions = [
                        {
                          evaluator.type = "gt";
                          evaluator.params = [ 0 ];
                        }
                      ];
                    };
                  }
                ];
                noDataState = "OK";
                execErrState = "Error";
                annotations = {
                  summary = a.title;
                  inherit (a) description;
                };
              }) (piConfig.monitoring.alerts or { });
            }
          ];
        }
      );

      # Combine each daemon file's contributed datasource yaml, the alerting
      # files and the dashboards provider config into one provisioning tree
      # Grafana can scan.
      grafanaProvisioning = pkgs.linkFarm "grafana-provisioning" (
        lib.mapAttrsToList (key: path: {
          name = "datasources/${key}.yaml";
          inherit path;
        }) cfg.datasources
        ++ lib.mapAttrsToList (key: path: {
          name = "alerting/${key}.yaml";
          inherit path;
        }) (cfg.grafanaAlerting // { rules = alertRules; })
        ++ [
          {
            name = "dashboards/dashboards.yaml";
            path = pkgs.writeText "dashboards-provider.yaml" ''
              apiVersion: 1
              providers:
                - name: home-server
                  folder: Home Server
                  type: file
                  allowUiUpdates: true
                  options:
                    path: ${dashboards}
            '';
          }
        ]
      );

      grafanaConfig = pkgs.writeText "grafana.ini" ''
        [paths]
        data = ${cfg.grafanaDataDir}/data
        logs = ${cfg.grafanaDataDir}/logs
        plugins = ${cfg.grafanaDataDir}/plugins
        provisioning = ${grafanaProvisioning}

        [server]
        http_addr = ${cfg.bindAddress}
        http_port = ${toString port}
        domain = grafana.home-server
        root_url = http://grafana.home-server/

        [users]
        allow_sign_up = false

        [analytics]
        reporting_enabled = false
        check_for_updates = false
      '';
    in
    {
      options.monitoring = {
        grafanaDataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/grafana";
        };

        grafanaAlerting = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          internal = true;
          description = ''
            Extra alerting provisioning files (contact points, notification
            policies), keyed by base filename (`alerting/<key>.yaml`).
          '';
        };

        grafanaEnvironmentFiles = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          internal = true;
          description = ''
            `KEY=value` files loaded into Grafana's environment at start, for
            provisioning files to reference as `''${KEY}`. Grafana waits for
            each to exist, since agenix decrypts them at boot.
          '';
        };
      };

      config = {
        daemonUsers.grafana = {
          uid = 481;
          dirs = [
            cfg.grafanaDataDir
            "${cfg.grafanaDataDir}/data"
            "${cfg.grafanaDataDir}/logs"
            "${cfg.grafanaDataDir}/plugins"
          ];
          logs = [
            "/var/log/grafana.log"
            "/var/log/grafana.err"
          ];
        };

        launchd.daemons.grafana.serviceConfig = {
          Label = "com.grafana.grafana";
          UserName = "grafana";
          GroupName = "grafana";
          # See wait4path rationale on the prometheus daemon.
          ProgramArguments =
            let
              exe = "${pkgs.grafana}/bin/grafana";
            in
            [
              "/bin/sh"
              "-c"
              (
                ''
                  /bin/wait4path "$0"
                ''
                # Polled, not wait4path: that only re-checks on a mount, so a
                # file agenix writes after Grafana starts never wakes it.
                + lib.concatMapStrings (f: ''
                  while [ ! -r ${f} ]; do sleep 1; done
                  set -a; . ${f}; set +a
                '') cfg.grafanaEnvironmentFiles
                + ''
                  exec "$0" "$@"
                ''
              )
              exe
              "server"
              "--config=${grafanaConfig}"
              "--homepath=${pkgs.grafana}/share/grafana"
            ];
          WorkingDirectory = "${cfg.grafanaDataDir}/data";
          RunAtLoad = true;
          KeepAlive = true;
          ThrottleInterval = 60;
          StandardOutPath = "/var/log/grafana.log";
          StandardErrorPath = "/var/log/grafana.err";
        };
      };
    };
}
