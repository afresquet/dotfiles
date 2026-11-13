{
  lib,
  config,
  ...
}:
let
  cfg = config.monitoring;
in
{
  imports = [
    ./options.nix
    ./alloy.nix
    ./exporters.nix
    ../../caddy/nixos.nix
    ../../dashboard/nixos.nix
  ];

  config = lib.mkIf cfg.enable {
    # ───────────────────────── Reverse proxy to Mac ─────────────────────────
    # When the Mac Mini is running Prometheus + Grafana, expose them under
    # the same *.home-server scheme as everything else by proxying through
    # Caddy on the Pi.
    reverseProxy.services = lib.mkIf (cfg.serverHost != null) {
      grafana = {
        host = "grafana.home-server";
        upstream = "${cfg.serverHost}:3000";
      };
      prometheus = {
        host = "prometheus.home-server";
        upstream = "${cfg.serverHost}:9090";
      };
    };

    dashboard.services = lib.mkIf (cfg.serverHost != null) {
      grafana = {
        group = "System";
        name = "Grafana";
        href = "http://grafana.home-server/";
        icon = "grafana.png";
        description = "Metrics dashboards";
        # Homepage's grafana widget only does basic auth (username+password,
        # base64'd into Authorization: Basic). Grafana service-account tokens
        # want Bearer auth, so we use the admin user's real password instead.
        # `version: 2` is required for Grafana > 10.4 (we're on 13).
        widget = {
          type = "grafana";
          version = 2;
          url = "http://grafana.home-server";
          username = "admin";
          password = "{{HOMEPAGE_VAR_GRAFANA_PASSWORD}}";
        };
      };
      prometheus = {
        group = "System";
        name = "Prometheus";
        href = "http://prometheus.home-server/";
        icon = "prometheus.png";
        description = "Metrics database";
        widget = {
          type = "prometheus";
          url = "http://prometheus.home-server";
        };
      };
    };

    # ───────────────────────── Firewall ─────────────────────────
    # Derived from the contributed exporter ports so service modules don't
    # have to remember to open firewall holes — declaring an exporter is
    # enough.
    networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = map (e: e.port) (
      lib.attrValues config.monitoring.exporters
    );

    # ───────────────────────── systemd accounting ─────────────────────────
    # CPU/memory/IO/task accounting per unit so systemd_exporter and cAdvisor
    # report the most data.
    systemd.settings.Manager = {
      DefaultCPUAccounting = true;
      DefaultMemoryAccounting = true;
      DefaultIOAccounting = true;
      DefaultTasksAccounting = true;
    };
  };
}
