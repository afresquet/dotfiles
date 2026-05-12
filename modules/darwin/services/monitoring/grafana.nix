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

  mkDashboard =
    { id ? null, revision ? null, url ? null, hash ? null, json ? null, name, extraFilter ? "." }:
    let
      raw =
        if json != null then json
        else pkgs.fetchurl {
          url = if url != null
            then url
            else "https://grafana.com/api/dashboards/${toString id}/revisions/${toString revision}/download";
          inherit hash;
        };
    in pkgs.runCommand "grafana-dashboard-${name}.json" {
      nativeBuildInputs = [ pkgs.jq ];
    } ''
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
      path = mkDashboard { inherit (d) id revision url hash json extraFilter; inherit name; };
    }) piDashboards
  );

  # Combine each sub-module's contributed datasource yaml + the dashboards
  # provider config into one provisioning tree Grafana can scan.
  grafanaProvisioning = pkgs.linkFarm "grafana-provisioning" (
    lib.mapAttrsToList (key: path: {
      name = "datasources/${key}.yaml";
      inherit path;
    }) cfg._datasources
    ++ [{
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
    }]
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
  options.monitoring.grafanaDataDir = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/grafana";
  };

  config = lib.mkIf cfg.enable {
    monitoring._activationDirs = [
      "${cfg.grafanaDataDir}/data"
      "${cfg.grafanaDataDir}/logs"
      "${cfg.grafanaDataDir}/plugins"
    ];

    launchd.daemons.grafana = {
      serviceConfig = {
        Label = "com.grafana.grafana";
        ProgramArguments = [
          "${pkgs.grafana}/bin/grafana"
          "server"
          "--config=${grafanaConfig}"
          "--homepath=${pkgs.grafana}/share/grafana"
        ];
        WorkingDirectory = "${cfg.grafanaDataDir}/data";
        RunAtLoad = true;
        KeepAlive = true;
        # See ThrottleInterval rationale on the prometheus daemon.
        ThrottleInterval = 60;
        StandardOutPath = "/var/log/grafana.log";
        StandardErrorPath = "/var/log/grafana.err";
      };
    };
  };
}
