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

  # Mullvad assigns a per-key IP via the WireGuard config. Hardcoding it in
  # serverConfig means it goes stale every time the WG key/server changes;
  # discover it from wg0 at startup instead. Runs inside the wg namespace
  # (qbittorrent.service is vpn-confined), so wg0 is the local interface.
  applyInterfaceAddressScript = pkgs.writeShellScript "qbittorrent-apply-interface-address" ''
    set -eu
    IP=$(${pkgs.iproute2}/bin/ip -j -4 addr show wg0 | ${pkgs.jq}/bin/jq -r '.[0].addr_info[0].local')
    ${pkgs.gnused}/bin/sed -i "s|WG_INTERFACE_ADDRESS_PLACEHOLDER|$IP|" "${configFile}"
  '';

  # Bridge subnet derived from vpn-confinement's bridgeAddress (default
  # 192.168.15.5/24). Tracks any future override instead of hardcoding the
  # default the upstream module ships with.
  bridgeSubnet =
    let
      parts = lib.splitString "." config.vpnNamespaces.${config.vpn.namespace}.bridgeAddress;
    in
    "${lib.concatStringsSep "." (lib.take 3 parts)}.0/24";
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
        ExecStartPre = lib.mkAfter [
          "${applyPasswordScript}"
          "${applyInterfaceAddressScript}"
        ];
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
          # Skip auth for the wg bridge subnet so the prometheus exporter
          # (running on the host) can scrape without credentials. The bridge
          # is internal-only — nothing on the LAN can reach this subnet.
          "WebUI\\AuthSubnetWhitelistEnabled" = (config.vpn.enable or false);
          "WebUI\\AuthSubnetWhitelist" = bridgeSubnet;
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
          # Mullvad. The InterfaceAddress placeholder is substituted at
          # service start by applyInterfaceAddressScript (above), so rotating
          # WG keys / Mullvad servers no longer requires editing this file.
          "Session\\Interface" = "wg0";
          "Session\\InterfaceName" = "wg0";
          "Session\\InterfaceAddress" = "WG_INTERFACE_ADDRESS_PLACEHOLDER";
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

    # ─── Monitoring ───
    # esanchezm/prometheus-qbittorrent-exporter scrapes the qBittorrent WebUI
    # API. It runs in the host namespace (not the wg one) so the firewall
    # interface for monitoring (tailscale0) is reachable; it dials qBittorrent
    # via the wg bridge address. The auth-bypass on the bridge subnet means
    # we don't need to plumb the WebUI password through another agenix secret
    # (the existing one stores a PBKDF2 hash, not the plaintext we'd need).
    systemd.services.prometheus-qbittorrent-exporter = {
      description = "Prometheus qBittorrent exporter";
      wantedBy = [ "multi-user.target" ];
      after = [ "qbittorrent.service" ] ++ lib.optional (config.vpn.enable or false) "wg.service";
      serviceConfig = {
        ExecStart = "${pkgs.prometheus-qbittorrent-exporter}/bin/qbit-exp";
        Environment = [
          "QBITTORRENT_BASE_URL=http://${
            if (config.vpn.enable or false)
            then config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress
            else "127.0.0.1"
          }:${toString cfg.webuiPort}"
          "QBITTORRENT_USERNAME=admin"
          # Auth bypass on the wg bridge subnet means any password is accepted.
          "QBITTORRENT_PASSWORD=ignored"
          "EXPORTER_PORT=17871"
          # Expose `qbittorrent_torrent_info` and friends. These are
          # high-cardinality (one series per torrent) but the matching
          # dashboard's torrent-list panels need them. ~hundreds of series
          # max for a typical home setup — well within Prometheus's noise floor.
          "ENABLE_HIGH_CARDINALITY=true"
          "ENABLE_INCREASED_CARDINALITY=true"
        ];
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = 10;
      };
    };

    monitoring.exporters.qbittorrent = lib.mkIf (config.monitoring.enable or false) {
      port = 17871;
    };
    monitoring.dashboards.qbittorrent = lib.mkIf (config.monitoring.enable or false) {
      # Nixpkgs `prometheus-qbittorrent-exporter` ships martabal's fork
      # (binary `qbit-exp`), not caseyscarborough's — different metric set,
      # so the grafana.com dashboards (14708, 15116) have broken panels.
      # The matching dashboard lives in the fork's repo, pinned to the
      # exporter version we run.
      url = "https://raw.githubusercontent.com/martabal/qbittorrent-exporter/v1.13.0/grafana/dashboard.json";
      hash = "sha256-GFH+qQv7A9KGb0HW2NuBvv3YA4lEiEL0BcAftd/7vnc=";
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
