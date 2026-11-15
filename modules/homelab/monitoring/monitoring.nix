# Prometheus, Grafana and Loki: exporters and dashboards declared on the Pi
# (nixos), the server stack on the Mac mini (darwin), which reads the Pi's
# declarations through piConfig.
{ inputs, self, ... }:
{
  flake.modules.nixos.monitoring =
    { lib, config, ... }:
    let
      cfg = config.monitoring;
    in
    {
      imports = [
        self.modules.nixos.monitoring-options
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
        # prometheus.nix, grafana.nix and loki.nix contribute their datasource
        # yaml and data dirs through these, so each daemon's wiring stays in its
        # own file.

        datasources = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          internal = true;
          description = ''
            Grafana datasource provisioning files contributed by the daemon files,
            keyed by base filename (the resulting path is `datasources/<key>.yaml`).
          '';
        };

        daemons = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                uid = lib.mkOption {
                  type = lib.types.int;
                  description = ''
                    uid and gid of the daemon's user and group. Below 500 so macOS
                    keeps it off the login window, like its own daemon accounts.
                  '';
                };
                dirs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "Directories created at activation and owned by the daemon.";
                };
                logs = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ ];
                  description = "The daemon's StandardOutPath/StandardErrorPath, owned by it.";
                };
              };
            }
          );
          default = { };
          internal = true;
          description = ''
            One hidden system user and group per daemon, keyed by the name its
            launchd UserName/GroupName uses. They listen on the tailnet, so a hole
            in one of them shouldn't come with root and the Nix signing key the
            Pis trust.
          '';
        };
      };

      config = {
        # The Pi declares its exporters, dashboards and probe URLs; the server
        # stack here reads them from its evaluated config.
        _module.args.piConfig = self.nixosConfigurations.Home-Server.config;

        # HA's long-lived access token; Prometheus reads it via bearer_token_file
        # in the home-assistant scrape job (see prometheus.nix).
        age.secrets.home-assistant-llat = {
          file = ../../../secrets/home-assistant-llat.age;
          owner = "prometheus";
        };

        # Grafana admin password; read by `export-grafana-dashboard` to round-trip
        # UI edits via the Grafana HTTP API.
        age.secrets.grafana-password.file = ../../../secrets/grafana-password.age;

        # Round-trip dashboard edits made in Grafana's UI back into the flake.
        # Lives here (with the rest of the Grafana wiring) rather than in the
        # mac-mini host config because it's only useful where Grafana runs.
        environment.systemPackages = [ pkgs.export-grafana-dashboard ];

        users = {
          knownUsers = lib.attrNames cfg.daemons;
          knownGroups = lib.attrNames cfg.daemons;
          users = lib.mapAttrs (name: d: {
            inherit (d) uid;
            gid = d.uid;
            description = name;
            home = "/var/empty";
            shell = "/usr/bin/false";
            isHidden = true;
          }) cfg.daemons;
          groups = lib.mapAttrs (name: d: {
            gid = d.uid;
            description = name;
          }) cfg.daemons;
        };

        # Hooked into the wired-in `postActivation` slot because nix-darwin
        # doesn't reliably run custom slots; it runs after the users slot, so the
        # owners exist. Data written back when the daemons ran as root is handed
        # over once, when a directory isn't the daemon's yet.
        system.activationScripts.postActivation.text = lib.mkAfter (
          lib.concatStrings (
            lib.mapAttrsToList (
              name: d:
              lib.concatMapStrings (dir: ''
                install -d -m 0755 -o ${name} -g ${name} ${dir}
                [ "$(stat -f %u ${dir})" = ${toString d.uid} ] || chown -R ${name}:${name} ${dir}
              '') d.dirs
              + lib.concatMapStrings (log: ''
                touch ${log}
                chown ${name}:${name} ${log}
              '') d.logs
            ) cfg.daemons
          )
        );
      };
    };
}
