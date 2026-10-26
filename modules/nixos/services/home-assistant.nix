{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.home-assistant-container;
  hacsSrc = pkgs.fetchzip {
    url = "https://github.com/hacs/integration/releases/download/${cfg.hacs.version}/hacs.zip";
    hash = cfg.hacs.hash;
    stripRoot = false;
  };
  monitoringEnabled = config.monitoring.enable or false;

  # Body of HA's `prometheus:` integration. Drops as the include target so
  # we own the metric filter declaratively without touching configuration.yaml.
  prometheusYaml = builtins.toFile "ha-prometheus.yaml" ''
    # Nix-managed (modules/nixos/services/home-assistant.nix). Edit there.
    filter:
      include_domains:
        - sensor
        - binary_sensor
        - light
        - switch
        - climate
        - person
        - sun
        - weather
  '';

  # HA packages (https://www.home-assistant.io/docs/configuration/packages/),
  # one YAML file each, loaded from <dataDir>/packages. The directory is fully
  # Nix-owned: it's wiped and repopulated on every start.
  packagesDir = pkgs.linkFarm "ha-packages" (
    lib.mapAttrsToList (name: path: {
      name = "${name}.yaml";
      inherit path;
    }) cfg.packages
  );

  # Minimal hand-written HA dashboard. No good Prometheus-based HA dashboard
  # exists on grafana.com (most are InfluxDB). Stored as a static JSON file
  # so UI edits round-trip via `export-grafana-dashboard`.
  haDashboardJson = ./monitoring/dashboards/home-assistant.json;
in
{
  options = {
    home-assistant-container = {
      enable = lib.mkEnableOption "Home Assistant (container)" // {
        default = false;
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/home-assistant";
        description = "Directory for Home Assistant persistent configuration.";
      };

      image = lib.mkOption {
        type = lib.types.str;
        default = "ghcr.io/home-assistant/home-assistant:stable";
        description = "Container image to run.";
      };

      packages = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        example = lib.literalExpression "{ dune_weaver = ./home-assistant/dune-weaver.yaml; }";
        description = ''
          Home Assistant packages, as name → YAML file. Installed into
          <dataDir>/packages and loaded via `homeassistant: packages:`.
          Entities and automations defined here are read-only in the UI.
        '';
      };


      hacs = {
        enable = lib.mkEnableOption "HACS (Home Assistant Community Store)";

        version = lib.mkOption {
          type = lib.types.str;
          default = "2.0.5";
          description = "HACS release tag to install.";
        };

        hash = lib.mkOption {
          type = lib.types.str;
          default = "sha256-iMomioxH7Iydy+bzJDbZxt6BX31UkCvqhXrxYFQV8Gw=";
          description = "SRI hash of the HACS release zip (unpacked).";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # HA skips a package whose name isn't a slug, logging only an error.
        assertion = lib.all (n: builtins.match "[a-z0-9_]+" n != null) (lib.attrNames cfg.packages);
        message = "home-assistant-container.packages names must match [a-z0-9_]+ (use underscores, not dashes).";
      }
    ];

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
    ];

    # HA's HomeKit Bridge integration assigns each bridge a TCP port starting
    # at 21063 and incrementing. mDNS (UDP 5353) is enough for iOS to discover
    # the bridge, but pairing/communication is TCP — without these open, iOS
    # sees the announce, gets a connection refused, and shows
    # "device not accessible". Range covers ~11 bridges, plenty.
    networking.firewall.allowedTCPPortRanges = [
      {
        from = 21063;
        to = 21073;
      }
    ];

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };

    reverseProxy.services.home-assistant = {
      host = "home-assistant.home-server";
      upstream = "127.0.0.1:8123";
    };

    dashboard.services.home-assistant = {
      group = "System";
      name = "Home Assistant";
      href = "http://home-assistant.home-server/";
      icon = "home-assistant.png";
      description = "Home automation";
      widget = {
        type = "homeassistant";
        url = "http://127.0.0.1:8123";
        key = "{{HOMEPAGE_VAR_HOMEASSISTANT_TOKEN}}";
      };
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.home-assistant = {
        image = cfg.image;
        autoStart = true;
        volumes = [
          "${cfg.dataDir}:/config"
          "/etc/localtime:/etc/localtime:ro"
          "/run/dbus:/run/dbus"
        ];
        environment = {
          TZ = config.time.timeZone;
        };
        extraOptions = [
          "--network=host"
          "--cap-add=NET_ADMIN"
          "--cap-add=NET_RAW"
          # Place the container payload inside the podman-home-assistant.service
          # cgroup so cAdvisor's per-unit metrics reflect actual usage.
          "--cgroups=split"
        ];
      };
    };

    # Sync HACS into the persistent config dir before the container starts.
    # Bind-mounting from /nix/store would require exposing the store inside
    # the container; copying keeps the container self-contained and lets HA
    # treat it as a normal custom_component.
    systemd.services.home-assistant-hacs-install = lib.mkIf cfg.hacs.enable {
      description = "Install HACS into Home Assistant config dir";
      wantedBy = [ "podman-home-assistant.service" ];
      before = [ "podman-home-assistant.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0755 ${cfg.dataDir}/custom_components
        rm -rf ${cfg.dataDir}/custom_components/hacs
        cp -r ${hacsSrc} ${cfg.dataDir}/custom_components/hacs
        chmod -R u+w ${cfg.dataDir}/custom_components/hacs
      '';
    };

    systemd.services.home-assistant-packages = lib.mkIf (cfg.packages != { }) {
      description = "Install Nix-managed Home Assistant packages";
      wantedBy = [ "podman-home-assistant.service" ];
      before = [ "podman-home-assistant.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        rm -rf ${cfg.dataDir}/packages
        install -d -m 0755 ${cfg.dataDir}/packages
        cp -L ${packagesDir}/*.yaml ${cfg.dataDir}/packages/
        chmod 0644 ${cfg.dataDir}/packages/*.yaml

        config=${cfg.dataDir}/configuration.yaml
        # Same idempotent-append approach as the prometheus include below,
        # seeding default_config on a fresh install. Bail out loudly if a
        # `homeassistant:` block was added by hand, rather than writing a
        # duplicate key HA would refuse to parse.
        [ -f "$config" ] || printf 'default_config:\n' > "$config"
        if ! ${pkgs.gnugrep}/bin/grep -Eq '^homeassistant:' "$config"; then
          printf '\n# Nix-managed (modules/nixos/services/home-assistant.nix).\nhomeassistant:\n  packages: !include_dir_named packages\n' \
            >> "$config"
        elif ! ${pkgs.gnugrep}/bin/grep -Eq '^\s+packages: !include_dir_named packages' "$config"; then
          echo "configuration.yaml has a homeassistant: block without the packages include" >&2
          exit 1
        fi
      '';
    };

    # ─── Monitoring ───
    # HA's built-in /api/prometheus endpoint serves metrics for every entity.
    # Requires a long-lived access token (LLAT) on the scraper + a `prometheus:`
    # block in HA's config. We own the integration's body declaratively via
    # an `!include`d sub-file; configuration.yaml gets the include directive
    # idempotently appended on first run.
    systemd.services.home-assistant-prometheus-config = lib.mkIf monitoringEnabled {
      description = "Install Prometheus integration config for HA";
      wantedBy = [ "podman-home-assistant.service" ];
      before = [ "podman-home-assistant.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -m 0644 ${prometheusYaml} ${cfg.dataDir}/prometheus.yaml

        config=${cfg.dataDir}/configuration.yaml

        # Fresh install: HA hasn't booted yet, so configuration.yaml doesn't
        # exist. Seed it with default_config (what HA itself writes on first
        # run) plus our include, so the integration is wired from boot one.
        if [ ! -f "$config" ]; then
          printf 'default_config:\n\n# Nix-managed (modules/nixos/services/home-assistant.nix).\nprometheus: !include prometheus.yaml\n' \
            > "$config"
          exit 0
        fi

        # Existing install: only append if there's no `prometheus:` top-level
        # key already (in any form). Matching on `^prometheus:` catches both
        # `prometheus: !include …` and inline `prometheus:` blocks, avoiding
        # the duplicate-key parse error HA would otherwise hit.
        if ! ${pkgs.gnugrep}/bin/grep -Eq '^prometheus:' "$config"; then
          printf '\n# Nix-managed (modules/nixos/services/home-assistant.nix).\nprometheus: !include prometheus.yaml\n' \
            >> "$config"
        fi
      '';
    };

    # Container needs to restart when our integration config changes.
    systemd.services.podman-home-assistant.restartTriggers =
      lib.optional monitoringEnabled prometheusYaml
      ++ lib.optional (cfg.packages != { }) packagesDir;

    monitoring.exporters.home-assistant = lib.mkIf monitoringEnabled {
      port = 8123;
      metricsPath = "/api/prometheus";
      bearerTokenFile = "/run/agenix/home-assistant-llat";
    };
    monitoring.dashboards.home-assistant = lib.mkIf monitoringEnabled {
      json = haDashboardJson;
    };
  };
}
