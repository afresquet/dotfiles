{
  lib,
  config,
  ...
}:
let
  cfg = config.qbittorrent;
in
{
  options.qbittorrent = {
    enable = lib.mkEnableOption "qBittorrent" // {
      default = false;
    };

    profileDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd/qbittorrent";
      description = "Directory for qBittorrent profile (config + state).";
    };

    webuiPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "qBittorrent Web UI port (proxied externally).";
    };

    torrentingPort = lib.mkOption {
      type = lib.types.port;
      default = 6881;
      description = "qBittorrent peer/torrenting port (TCP+UDP).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.profileDir} 0750 qbittorrent qbittorrent -"
    ];

    services.qbittorrent = {
      enable = true;
      profileDir = cfg.profileDir;
      webuiPort = cfg.webuiPort;
      torrentingPort = cfg.torrentingPort;
      openFirewall = true;
      serverConfig.Preferences = {
        "WebUI\\HostHeaderValidation" = false;
      };
    };

    reverseProxy.services.qbittorrent = {
      host = "torrent.home-server";
      upstream = "127.0.0.1:${toString cfg.webuiPort}";
    };
  };
}
