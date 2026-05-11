{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.qbittorrent;

  configFile = "${cfg.profileDir}/qBittorrent/config/qBittorrent.conf";

  applyPasswordScript = pkgs.writeShellScript "qbittorrent-apply-password" ''
    set -eu
    read -r HASH < "${config.age.secrets.qbittorrent-webuipw.path}"
    ${pkgs.gnused}/bin/sed -i "s|PBKDF2_PLACEHOLDER|$HASH|" "${configFile}"
  '';
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

    downloadsDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/hdd/downloads/torrents";
      description = "Default save path for completed torrents.";
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
    age.secrets.qbittorrent-webuipw = {
      file = ../../../secrets/qbittorrent-webuipw.age;
      owner = "qbittorrent";
      group = "qbittorrent";
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.profileDir} 0750 qbittorrent qbittorrent -"
    ];

    systemd.services.qbittorrent.serviceConfig = {
      ExecStartPre = lib.mkAfter [ "${applyPasswordScript}" ];
      # 0002 → new files are 0664 (group-writable), needed so users in `media`
      # can create hardlinks to qBittorrent's downloads (kernel
      # fs.protected_hardlinks denies link() when the caller can read but not
      # write the source file).
      UMask = "0002";
    };

    services.qbittorrent = {
      enable = true;
      profileDir = cfg.profileDir;
      webuiPort = cfg.webuiPort;
      torrentingPort = cfg.torrentingPort;
      openFirewall = true;
      serverConfig = {
        Preferences = {
          "WebUI\\HostHeaderValidation" = false;
          "Downloads\\SavePath" = "${cfg.downloadsDir}/";
          "WebUI\\Username" = "admin";
          "WebUI\\Password_PBKDF2" = ''"@ByteArray(PBKDF2_PLACEHOLDER)"'';
        };
        BitTorrent = {
          # Stop seeding once either condition is met, then remove the torrent
          # and delete its files from /downloads (the *arr import is hardlinked
          # to /media so this doesn't affect the library).
          "Session\\GlobalMaxRatio" = 1.0;
          "Session\\GlobalMaxSeedingMinutes" = 2880; # 48 hours
          "Session\\MaxRatioAction" = 3; # 3 = remove torrent + delete files
        };
      };
    };

    reverseProxy.services.qbittorrent = {
      host = "torrent.home-server";
      upstream = "127.0.0.1:${toString cfg.webuiPort}";
    };
  };
}
