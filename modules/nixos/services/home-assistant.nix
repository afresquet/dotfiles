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
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
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
  };
}
