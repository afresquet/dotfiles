{
  lib,
  config,
  ...
}:
let
  cfg = config.slskd;
  vpnEnabled = config.vpn.enable or false;
  namespaceAddr =
    if vpnEnabled then
      config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress
    else
      "127.0.0.1";
in
{
  options.slskd = {
    enable = lib.mkEnableOption "slskd Soulseek client" // {
      default = false;
    };

    webuiPort = lib.mkOption {
      type = lib.types.port;
      default = 5030;
      description = "slskd web UI / REST API port (proxied externally).";
    };

    peerPort = lib.mkOption {
      type = lib.types.port;
      default = 50300;
      description = ''
        Soulseek peer port. Mullvad doesn't do port forwarding, so inbound
        peer connections from the open internet won't reach us — outbound-
        initiated transfers still work, just with fewer total peers. Same
        caveat as qBittorrent torrenting.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/slskd";
      description = ''
        Persistent state for slskd (config, database, logs). Mounted as /app
        in the container. Lives on the NVMe — actual downloaded files go to
        `downloadsDir` on the spinning HDD to avoid filling the root
        partition.
      '';
    };

    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd/downloads/soulseek";
      description = ''
        Where slskd writes completed Soulseek downloads. Mounted into the
        container as /downloads (and slskd pointed there via
        SLSKD_DOWNLOADS_DIR). Owned `root:media 2775` so other media-group
        consumers (Explo, Lidarr's slskd integration if added later) can read
        and hardlink without breaking the kernel's protected_hardlinks check.
      '';
    };

    incompleteDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd/downloads/soulseek-incomplete";
      description = ''
        Where slskd parks partial downloads before moving them to
        `downloadsDir` on completion. On the HDD too — incompletes for big
        FLAC albums can otherwise eat the root partition.
      '';
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "slskd/slskd:latest";
      description = "Container image to run.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}      0755 root root  -"
      # Setgid + media group so anything Explo/Lidarr later hardlinks out of
      # here keeps a sensible group. Same shape as /mnt/hdd/downloads/torrents.
      "d ${cfg.downloadsDir} 2775 root media -"
      "d ${cfg.incompleteDir} 2775 root media -"
    ];

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.slskd = {
        image = cfg.image;
        autoStart = true;
        volumes = [
          "${cfg.dataDir}:/app"
          "${cfg.downloadsDir}:/downloads"
          "${cfg.incompleteDir}:/incomplete"
        ];
        environment = {
          TZ = config.time.timeZone;
          # Lets the web UI persist slskd.yml edits — without this slskd is
          # read-only at runtime and config has to be hand-edited on disk.
          SLSKD_REMOTE_CONFIGURATION = "true";
          # Point slskd at the HDD-backed dirs (overrides slskd.yml). Without
          # these, completed and partial downloads land under /app on the
          # NVMe and can blow up the root partition on a big haul.
          SLSKD_DOWNLOADS_DIR = "/downloads";
          SLSKD_INCOMPLETE_DIR = "/incomplete";
        };
        extraOptions = [
          # Pin to the wg namespace so Soulseek peer traffic exits via Mullvad
          # (same privacy story as qBittorrent). Same pattern as Byparr in
          # arr.nix. caddy on the host reaches the UI via the namespace's
          # host-side bridge IP (192.168.15.1 by default).
          "--network=ns:/var/run/netns/${config.vpn.namespace}"
          "--dns=1.1.1.1"
          "--cgroups=split"
        ];
      };
    };

    # Tie podman-slskd's lifecycle to wg.service so we don't try to start
    # before the namespace exists.
    systemd.services.podman-slskd = lib.mkIf vpnEnabled {
      after = [ "wg.service" ];
      bindsTo = [ "wg.service" ];
      partOf = [ "wg.service" ];
    };

    vpnNamespaces = lib.mkIf vpnEnabled {
      ${config.vpn.namespace} = {
        # DNAT external traffic on the host (caddy) into the namespace on the
        # web UI port. Same shape as qBittorrent's portMappings.
        portMappings = [
          {
            from = cfg.webuiPort;
            to = cfg.webuiPort;
            protocol = "tcp";
          }
        ];
        # Accept inbound Soulseek peer port on wg0 — needed so DHT-like
        # outbound-initiated transfers don't drop after conntrack expires.
        openVPNPorts = [
          {
            port = cfg.peerPort;
            protocol = "tcp";
          }
        ];
      };
    };

    reverseProxy.services.slskd = {
      host = "slskd.home-server";
      upstream = "${namespaceAddr}:${toString cfg.webuiPort}";
    };

    dashboard.services.slskd = {
      group = "Downloads";
      name = "slskd";
      href = "http://slskd.home-server/";
      icon = "slskd.png";
      description = "Soulseek client (Mullvad)";
    };
  };
}
