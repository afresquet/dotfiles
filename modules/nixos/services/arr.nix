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
    services.prowlarr.enable = true;
    services.bazarr.enable = true;
    services.jellyseerr.enable = true;
    services.flaresolverr.enable = true;

    users.users =
      lib.mapAttrs (_: _: { extraGroups = [ "media" ]; }) mediaApps
      // lib.optionalAttrs (config.qbittorrent.enable or false) {
        qbittorrent.extraGroups = [ "media" ];
      };

    reverseProxy.services = lib.mapAttrs (name: port: {
      host = "${name}.home-server";
      upstream = "127.0.0.1:${toString port}";
    }) apps;
  };
}
