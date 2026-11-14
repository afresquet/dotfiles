# Prometheus, Grafana and Loki: exporters and dashboards declared on the Pi
# (nixos), the server stack on the Mac mini (darwin), which reads the Pi's
# declarations through piConfig.
{ inputs, self, ... }:
{
  flake.modules.nixos.monitoring =
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
        ./_nixos-options.nix
        ./_nixos-alloy.nix
        ./_nixos-exporters.nix
        self.modules.nixos.caddy
        self.modules.nixos.dashboard
      ];

      options.monitoring = {
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
      };

      config = {
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
    };

  flake.modules.darwin.monitoring =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.monitoring;
    in
    {
      imports = [
        inputs.agenix.darwinModules.default
        ./_darwin-prometheus.nix
        ./_darwin-grafana.nix
        ./_darwin-loki.nix
      ];

      options.monitoring = {

        targetHost = lib.mkOption {
          type = lib.types.str;
          default = "home-server";
          description = ''
            Hostname or IP of the machine running the exporters. Defaults to
            the Tailscale MagicDNS name; use the tailnet IP if MagicDNS is off.
          '';
        };

        bindAddress = lib.mkOption {
          type = lib.types.str;
          default = "0.0.0.0";
          description = ''
            Address Prometheus / Grafana / Loki bind to. Default exposes them
            on the tailnet so Caddy on the Pi can reverse-proxy them and log
            shippers can reach Loki.
          '';
        };

        scrapeInterval = lib.mkOption {
          type = lib.types.str;
          default = "15s";
        };

        # ─── Internal aggregators ───
        # Sub-modules contribute their own datasource yaml + data dirs through
        # these. Keeps each daemon's wiring self-contained without forcing the
        # default.nix to know about them.

        _datasources = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          internal = true;
          description = ''
            Grafana datasource provisioning files contributed by sub-modules,
            keyed by base filename (the resulting path is `datasources/<key>.yaml`).
          '';
        };

        _activationDirs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          internal = true;
          description = ''
            Paths each sub-module needs `mkdir -p`'d at activation. Default.nix
            emits a single `install -d` block from this aggregate.
          '';
        };
      };

      config = {
        # The Pi declares its exporters, dashboards and probe URLs; the server
        # stack here reads them from its evaluated config.
        _module.args.piConfig = self.nixosConfigurations.Home-Server.config;

        # HA's long-lived access token; Prometheus reads it via bearer_token_file
        # in the home-assistant scrape job (see prometheus.nix).
        age.secrets.home-assistant-llat.file = ../../../secrets/home-assistant-llat.age;

        # Grafana admin password; read by `export-grafana-dashboard` to round-trip
        # UI edits via the Grafana HTTP API.
        age.secrets.grafana-password.file = ../../../secrets/grafana-password.age;

        # Round-trip dashboard edits made in Grafana's UI back into the flake.
        # Lives here (with the rest of the Grafana wiring) rather than in the
        # mac-mini host config because it's only useful where Grafana runs.
        environment.systemPackages = [ pkgs.export-grafana-dashboard ];

        # Single postActivation block aggregates each sub-module's data dirs.
        # Hooked into the wired-in `postActivation` slot because nix-darwin
        # doesn't reliably run custom slots.
        system.activationScripts.postActivation.text = lib.mkAfter (
          lib.concatMapStringsSep "\n" (d: "install -d -m 0755 ${d}") cfg._activationDirs
        );
      };
    };
}
