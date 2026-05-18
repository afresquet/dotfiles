{
  lib,
  config,
  ...
}:
let
  cfg = config.musicseerr;
in
{
  options.musicseerr = {
    enable = lib.mkEnableOption "MusicSeerr music request & discovery (Lidarr / Navidrome / Jellyfin)" // {
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8688;
      description = "HTTP port MusicSeerr listens on (proxied externally).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/musicseerr";
      description = ''
        Parent directory for MusicSeerr's persistent state. The container's
        /app/config (config.json) and /app/cache (cover art, metadata, SQLite
        databases) are bind-mounted from <dataDir>/config and <dataDir>/cache.
      '';
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/habirabbu/musicseerr:latest";
      description = "Container image to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Image runs as PUID 1000. The bind-mount dirs must be writable by that
    # UID — not just their contents — because SQLite needs to create per-write
    # journal files in the cache dir, and "attempt to write a readonly
    # database" is what you get otherwise. `:U` on the volume only fixed the
    # contents, and tmpfiles' `d` rule re-asserts ownership on every boot, so
    # owning the dirs as 1000:1000 here is the durable fix.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}        0755 root root -"
      "d ${cfg.dataDir}/config 0755 1000 1000 -"
      "d ${cfg.dataDir}/cache  0755 1000 1000 -"
    ];

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.musicseerr = {
        image = cfg.image;
        autoStart = true;
        # Ownership of these dirs is handled by tmpfiles above (1000:1000),
        # so no `:U` is needed — and `:U` would only chown contents anyway,
        # leaving the mount-point dirs root-owned and unwritable.
        volumes = [
          "${cfg.dataDir}/config:/app/config"
          "${cfg.dataDir}/cache:/app/cache"
        ];
        environment = {
          TZ = config.time.timeZone;
          PORT = toString cfg.port;
        };
        extraOptions = [
          # Host network so MusicSeerr reaches Lidarr (8686), Navidrome (4533)
          # and Jellyfin (8096) on 127.0.0.1. Port 8688 is firewalled
          # externally (only 80 is allowed on tailscale0); caddy proxies via
          # host loopback. Same pattern as aurral.nix.
          "--network=host"
          # Place the container payload inside the podman-musicseerr.service
          # cgroup so cAdvisor's per-unit metrics reflect actual usage.
          "--cgroups=split"
        ];
      };
    };

    reverseProxy.services.musicseerr = {
      host = "musicseerr.home-server";
      upstream = "127.0.0.1:${toString cfg.port}";
      probePath = "/health";
    };

    dashboard.services.musicseerr = {
      group = "Media";
      name = "MusicSeerr";
      href = "http://musicseerr.home-server/";
      icon = "mdi-music-box-multiple";
      description = "Music requests (Lidarr)";
    };
  };
}
