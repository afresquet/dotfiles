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

    systemd.services.qbittorrent = {
      serviceConfig = {
        ExecStartPre = lib.mkAfter [ "${applyPasswordScript}" ];
        # 0002 → new files are 0664 (group-writable), needed so users in `media`
        # can create hardlinks to qBittorrent's downloads (kernel
        # fs.protected_hardlinks denies link() when the caller can read but not
        # write the source file).
        UMask = "0002";
      };
      vpnConfinement = lib.mkIf (config.vpn.enable or false) {
        enable = true;
        vpnNamespace = config.vpn.namespace;
      };
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
          # Stop seeding once either condition is met. Action = pause (not
          # remove): the *arr apps warn loudly if qBittorrent removes torrents
          # behind their back, because it desyncs their internal bookkeeping.
          # Let each *arr's own "Remove Completed Downloads" setting clean up
          # paused torrents via the qBittorrent API after a successful import.
          # Disk usage stays flat regardless because /downloads is hardlinked
          # into /media — both paths share the same inode.
          "Session\\GlobalMaxRatio" = 1.0;
          "Session\\GlobalMaxSeedingMinutes" = 2880; # 48 hours
          "Session\\MaxRatioAction" = 0; # 0 = pause torrent (was 3 = remove + delete)
          # Bind BitTorrent traffic to the WireGuard interface inside the VPN
          # namespace. Without all three, qBittorrent silently falls back to
          # binding nothing — and DHT/peer traffic never goes out through
          # Mullvad. The IP comes from Mullvad's per-key assignment in the WG
          # config (Address = ...); change it here if you rotate keys.
          "Session\\Interface" = "wg0";
          "Session\\InterfaceName" = "wg0";
          "Session\\InterfaceAddress" = "10.75.78.187";
        };
      };
    };

    dashboard.services.qbittorrent = {
      group = "Downloads";
      name = "qBittorrent";
      href = "http://torrent.home-server/";
      icon = "qbittorrent.png";
      description = "Torrent client (Mullvad)";
      widget = {
        type = "qbittorrent";
        url =
          if (config.vpn.enable or false) then
            "http://${config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress}:${toString cfg.webuiPort}"
          else
            "http://127.0.0.1:${toString cfg.webuiPort}";
        username = "admin";
        password = "{{HOMEPAGE_VAR_QBITTORRENT_PASSWORD}}";
      };
    };

    reverseProxy.services.qbittorrent = {
      host = "torrent.home-server";
      # When confined to the VPN namespace, caddy can't reach 127.0.0.1:<port>
      # (vpn-confinement only DNATs PREROUTING traffic). Proxy via the
      # namespace's bridge-side address instead.
      upstream =
        if (config.vpn.enable or false) then
          "${config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress}:${toString cfg.webuiPort}"
        else
          "127.0.0.1:${toString cfg.webuiPort}";
    };

    vpnNamespaces = lib.mkIf (config.vpn.enable or false) {
      ${config.vpn.namespace} = {
        portMappings = [
          {
            from = cfg.webuiPort;
            to = cfg.webuiPort;
            protocol = "tcp";
          }
        ];
        # Accept inbound on the BT port via the WG interface so DHT replies
        # (UDP) and any outbound-initiated peer connections aren't dropped by
        # the namespace's default-DROP INPUT chain after conntrack expires.
        openVPNPorts = [
          {
            port = cfg.torrentingPort;
            protocol = "both";
          }
        ];
      };
    };
  };
}
