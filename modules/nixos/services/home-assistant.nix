{
  lib,
  config,
  ...
}:
let
  cfg = config.home-assistant-container;
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
  };
}
