{
  lib,
  config,
  ...
}:
let
  cfg = config.arrStack;

  apps = {
    radarr = 7878;
    sonarr = 8989;
    lidarr = 8686;
    readarr = 8787;
    prowlarr = 9696;
    bazarr = 6767;
    jellyseerr = 5055;
  };

  # prowlarr and jellyseerr don't touch the filesystem, and their NixOS modules
  # use DynamicUser so we can't extend their group membership without breaking
  # the user declaration.
  mediaApps = lib.removeAttrs apps [
    "prowlarr"
    "jellyseerr"
  ];
in
{
  options.arrStack = {
    enable = lib.mkEnableOption "*arr suite + jellyseerr" // {
      default = false;
    };

    dataRoot = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd";
      description = "Root directory containing shared downloads/ and media/ subdirs.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataRoot}/downloads             2775 root media -"
      "d ${cfg.dataRoot}/downloads/torrents    2775 root media -"
      "d ${cfg.dataRoot}/downloads/incomplete  2775 root media -"
      "d ${cfg.dataRoot}/media                 2775 root media -"
      "d ${cfg.dataRoot}/media/movies          2775 root media -"
      "d ${cfg.dataRoot}/media/tv              2775 root media -"
      "d ${cfg.dataRoot}/media/music           2775 root media -"
      "d ${cfg.dataRoot}/media/books           2775 root media -"
    ];

    services.radarr.enable = true;
    services.sonarr.enable = true;
    services.lidarr.enable = true;
    services.readarr.enable = true;

    # The *arr apps run on the host; Prowlarr lives in the VPN namespace and
    # needs to reach them on the namespace's bridge side (192.168.15.5) to
    # push indexer config. Open just those ports on the wg-br interface so we
    # don't expose them anywhere else.
    networking.firewall.interfaces.wg-br = lib.mkIf (config.vpn.enable or false) {
      allowedTCPPorts = lib.attrValues (lib.filterAttrs (n: _: builtins.elem n [
        "radarr"
        "sonarr"
        "lidarr"
        "readarr"
      ]) apps);
    };
    services.prowlarr.enable = true;
    services.bazarr.enable = true;
    services.jellyseerr.enable = true;

    # Byparr is a FlareSolverr-compatible Cloudflare bypass with much better
    # success on current Cloudflare challenges. No nixpkgs package, so we run
    # the upstream container directly inside the VPN namespace by attaching
    # podman to the existing netns. Prowlarr's existing "FlareSolverr" indexer
    # proxy config keeps working unchanged (Byparr serves the same API).
    virtualisation.oci-containers = lib.mkIf (config.vpn.enable or false) {
      backend = "podman";
      containers.byparr = {
        image = "ghcr.io/thephaseless/byparr:latest";
        autoStart = true;
        environment = {
          TZ = config.time.timeZone;
          LOG_LEVEL = "info";
        };
        extraOptions = [
          "--network=ns:/var/run/netns/${config.vpn.namespace}"
          "--dns=1.1.1.1"
        ];
      };
    };

    systemd.services.podman-byparr = lib.mkIf (config.vpn.enable or false) {
      after = [ "wg.service" ];
      bindsTo = [ "wg.service" ];
      partOf = [ "wg.service" ];
    };

    users.users =
      lib.mapAttrs (_: _: { extraGroups = [ "media" ]; }) mediaApps
      // lib.optionalAttrs (config.qbittorrent.enable or false) {
        qbittorrent.extraGroups = [ "media" ];
      };

    reverseProxy.services = lib.mapAttrs (
      name: port:
      let
        # prowlarr is in the VPN namespace, so caddy must reach it via the
        # namespace's bridge IP rather than the host's 127.0.0.1.
        upstreamHost =
          if (config.vpn.enable or false) && name == "prowlarr" then
            config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress
          else
            "127.0.0.1";
      in
      {
        host = "${name}.home-server";
        upstream = "${upstreamHost}:${toString port}";
      }
    ) apps;

    # Confine prowlarr (the only native service that touches public indexer
    # sites) to the VPN namespace. Byparr runs as a container directly attached
    # to the namespace via --network=ns:..., so it doesn't need vpnConfinement.
    systemd.services.prowlarr.vpnConfinement = lib.mkIf (config.vpn.enable or false) {
      enable = true;
      vpnNamespace = config.vpn.namespace;
    };

    vpnNamespaces = lib.mkIf (config.vpn.enable or false) {
      ${config.vpn.namespace}.portMappings = [
        {
          from = 9696;
          to = 9696;
          protocol = "tcp";
        }
      ];
    };
  };
}
