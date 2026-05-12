{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.monitoring;
in
{
  imports = [
    inputs.agenix.darwinModules.default
    ./prometheus.nix
    ./grafana.nix
    ./loki.nix
  ];

  options.monitoring = {
    enable = lib.mkEnableOption "Prometheus + Grafana + Loki via launchd" // {
      default = false;
    };

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
        on the tailnet so Caddy on the Pi can reverse-proxy them and
        Promtail on the Pi can ship logs to Loki.
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

  config = lib.mkIf cfg.enable {
    # HA's long-lived access token; Prometheus reads it via bearer_token_file
    # in the home-assistant scrape job (see prometheus.nix).
    age.secrets.home-assistant-llat.file = ../../../../secrets/home-assistant-llat.age;

    # Grafana admin password; read by `export-grafana-dashboard` to round-trip
    # UI edits via the Grafana HTTP API.
    age.secrets.grafana-password.file = ../../../../secrets/grafana-password.age;

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
}
