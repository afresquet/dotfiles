{ inputs, self, ... }:
{
  flake.modules.nixos.explo =
    { lib, config, ... }:
    let
      cfg = config.explo;
      # When slskd is wg-confined (default), Explo (host network) reaches it via
      # the namespace's host-side bridge address rather than 127.0.0.1.
      slskdUrl = "http://${
        config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress
      }:${toString config.slskd.webuiPort}";
    in
    {
      imports = [
        self.modules.nixos.slskd
        self.modules.nixos.vpn
        self.modules.nixos.media-group
        inputs.agenix.nixosModules.default
        self.modules.nixos.caddy
        self.modules.nixos.dashboard
      ];

      options.explo = {
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

      config = {
        age.secrets.explo-env.file = ../../secrets/explo-env.age;

        # The image runs everything as root unless PUID/PGID are set. Its own
        # account instead, with media as its group so navidrome can read what it
        # downloads. Static because the container needs the number at
        # evaluation time.
        users.users.explo = {
          isSystemUser = true;
          uid = 402;
          group = "media";
          home = cfg.dataDir;
          description = "Explo";
        };

        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir}        0755 explo media -"
          "d ${cfg.dataDir}/config 0755 explo media -"
          # Takes over what it wrote back when it ran as root.
          "Z ${cfg.dataDir}        -    explo media -"
          # Setgid so files Explo writes inherit the media group → navidrome can
          # read them via its media-group membership.
          "d ${cfg.musicDir}       2775 explo media -"
        ];

        virtualisation.podman = {
          enable = true;
          autoPrune.enable = true;
        };

        virtualisation.oci-containers = {
          backend = "podman";
          containers.explo = {
            inherit (cfg) image;
            autoStart = true;
            volumes = [
              # Container-private state, owned by explo through tmpfiles above.
              "${cfg.dataDir}/config:/opt/explo/config"
              # Shared with navidrome. Explo writes as PUID; the setgid+media
              # group on the dir keeps the group right.
              "${cfg.musicDir}:/data"
            ]
            # MIGRATE_DOWNLOADS=true moves files from slskd's download dir into
            # /data; needs the slskd dir mounted into Explo so the rename(2) is
            # cross-mount-aware. The path inside Explo (/slskd/) matches the
            # default SLSKD_DIR Explo reads from.
            ++ [ "${config.slskd.downloadsDir}:/slskd" ];
            environmentFiles = [ config.age.secrets.explo-env.path ];
            environment = {
              TZ = config.time.timeZone;
              # start.sh remaps its explo user to these and runs the web UI and
              # explo through su-exec. Only crond and the yt-dlp self-update
              # stay root inside the container.
              PUID = toString config.users.users.explo.uid;
              PGID = toString config.users.groups.media.gid;
              WEB_UI = "true";
              # Navidrome speaks the Subsonic API.
              EXPLO_SYSTEM = "subsonic";
              SYSTEM_URL = "http://127.0.0.1:4533";
            }
            // {
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
    };
}
