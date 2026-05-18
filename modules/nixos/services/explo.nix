{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.explo;
  slskdEnabled = config.slskd.enable or false;
  # When slskd is wg-confined (default), Explo (host network) reaches it via
  # the namespace's host-side bridge address rather than 127.0.0.1.
  slskdUrl =
    if slskdEnabled then
      "http://${
        if (config.vpn.enable or false) then
          config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress
        else
          "127.0.0.1"
      }:${toString config.slskd.webuiPort}"
    else
      null;
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  options.explo = {
    enable = lib.mkEnableOption "Explo — ListenBrainz-driven Discover-Weekly-style downloader" // {
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7288;
      description = "Explo web UI port (proxied externally).";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/explo";
      description = ''
        Container-private state directory. <dataDir>/config holds Explo's
        playlist cache + cover art (mounted as /opt/explo/config in the
        container).
      '';
    };

    musicDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd/media/music/explo";
      description = ''
        Where Explo deposits downloaded tracks. Must live under Navidrome's
        MusicFolder so they're picked up on the next scan. Mounted as /data
        in the container — but NOT with `:U`, since this directory is shared
        with the navidrome user (which reads via the `media` group).
      '';
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/lumepart/explo:latest";
      description = "Container image to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.explo-env.file = ../../../secrets/explo-env.age;

    users.groups.media = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}        0755 root root  -"
      "d ${cfg.dataDir}/config 0755 root root  -"
      # 2775 root:media + setgid so files Explo writes inherit the media group
      # → navidrome can read them via its media-group membership.
      "d ${cfg.musicDir}       2775 root media -"
    ];

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.explo = {
        image = cfg.image;
        autoStart = true;
        volumes = [
          # Container-private state: :U lets podman chown to the container's
          # UID on first start (safe — only Explo touches this tree).
          "${cfg.dataDir}/config:/opt/explo/config:U"
          # Shared with navidrome — NO :U. Explo writes as its container UID;
          # the setgid+media-group on the parent dir keeps the group right.
          "${cfg.musicDir}:/data"
        ]
        # MIGRATE_DOWNLOADS=true moves files from slskd's download dir into
        # /data; needs the slskd dir mounted into Explo so the rename(2) is
        # cross-mount-aware. The path inside Explo (/slskd/) matches the
        # default SLSKD_DIR Explo reads from.
        ++ lib.optional slskdEnabled "${config.slskd.downloadsDir}:/slskd";
        environmentFiles = [ config.age.secrets.explo-env.path ];
        environment = {
          TZ = config.time.timeZone;
          WEB_UI = "true";
          # Navidrome speaks the Subsonic API.
          EXPLO_SYSTEM = "subsonic";
          SYSTEM_URL = "http://127.0.0.1:4533";
        }
        // lib.optionalAttrs slskdEnabled {
          DOWNLOAD_SERVICES = "slskd";
          SLSKD_URL = slskdUrl;
          MIGRATE_DOWNLOADS = "true";
        };
        extraOptions = [
          # Host network so SYSTEM_URL=http://127.0.0.1:4533 reaches Navidrome.
          # Port 7288 is firewalled externally (only 80 is allowed on
          # tailscale0); caddy proxies via host loopback.
          "--network=host"
          # Place the container payload inside the podman-explo.service cgroup
          # so cAdvisor's per-unit metrics reflect actual usage.
          "--cgroups=split"
        ];
      };
    };

    reverseProxy.services.explo = {
      host = "explo.home-server";
      upstream = "127.0.0.1:${toString cfg.port}";
    };

    dashboard.services.explo = {
      group = "Media";
      name = "Explo";
      href = "http://explo.home-server/";
      icon = "mdi-compass-outline";
      description = "ListenBrainz auto-discovery";
    };
  };
}
