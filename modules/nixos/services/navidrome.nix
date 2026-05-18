{
  lib,
  config,
  ...
}:
let
  cfg = config.navidrome;
in
{
  options.navidrome = {
    enable = lib.mkEnableOption "Navidrome Subsonic-compatible music server" // {
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4533;
      description = "Navidrome HTTP port (proxied externally).";
    };

    musicFolder = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd/media/music";
      description = ''
        Music library root. Read by Navidrome's scanner. The arrStack module
        creates this as `root:media 2775`, so we add the navidrome user to the
        media group for read access.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.media = { };
    users.users.navidrome.extraGroups = [ "media" ];

    services.navidrome = {
      enable = true;
      openFirewall = false;
      settings = {
        Address = "127.0.0.1";
        Port = cfg.port;
        MusicFolder = cfg.musicFolder;
        # Anonymous telemetry — off by default in the module but make it
        # explicit here so a future upstream flip doesn't silently turn it on.
        EnableInsightsCollector = false;
      };
    };

    reverseProxy.services.navidrome = {
      host = "navidrome.home-server";
      upstream = "127.0.0.1:${toString cfg.port}";
    };

    dashboard.services.navidrome = {
      group = "Media";
      name = "Navidrome";
      href = "http://navidrome.home-server/";
      icon = "navidrome.png";
      description = "Music streaming (Subsonic)";
    };
  };
}
