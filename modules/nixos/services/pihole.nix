{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.pihole;
  proxy = config.reverseProxy or { enable = false; services = { }; dnsTarget = null; };
  proxyHostnames = lib.concatLists (
    lib.mapAttrsToList (_: svc: [ svc.host ] ++ svc.aliases) proxy.services
  );
  # Static path used both at config-time (for an explicit dnsTarget) and at
  # runtime (substituted into the rendered FTLCONF_dns_hosts env file when the
  # IP is auto-discovered from tailscaled).
  dnsHostEntries = ip:
    lib.concatStringsSep ";" (map (h: "${ip} ${h}") proxyHostnames);
  shouldServeProxyDns = (proxy.enable or false) && proxyHostnames != [ ];
  hasStaticDnsTarget = (proxy.dnsTarget or null) != null;

  # Forward queries for the user's Tailscale MagicDNS suffix to tailscaled's
  # local resolver, so hostnames like alvaros-mac-mini.<suffix> resolve from
  # the Pi (used for Caddy's reverse_proxy upstreams). Scoped to the user's
  # tailnet, not all of .ts.net, to keep the blast radius minimal.
  tailnetDnsConf = pkgs.writeText "tailnet-magicdns.conf" ''
    server=/${config.tailnet.domain}/100.100.100.100
  '';
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  options = {
    pihole = {
      enable = lib.mkEnableOption "Pi-hole DNS sinkhole" // {
        default = false;
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/pihole";
        description = "Directory for Pi-hole persistent state.";
      };

      upstreamDns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "1.1.1.1"
          "1.0.0.1"
        ];
        description = "Upstream DNS servers Pi-hole forwards queries to.";
      };

      adminPort = lib.mkOption {
        type = lib.types.port;
        default = 8081;
        description = "Localhost port the admin UI is exposed on (proxied externally).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.pihole-webpassword.file = ../../../secrets/pihole-webpassword.age;

    # Free port 53 so the container can bind it.
    services.resolved.enable = false;

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 root root -"
      "d ${cfg.dataDir}/etc-pihole 0755 root root -"
      "d ${cfg.dataDir}/etc-dnsmasq.d 0755 root root -"
      # Force-copy the tailnet forwarder snippet into the dnsmasq.d bind mount
      # on every activation. The container reads it on startup; the
      # restartTriggers below ensure podman-pihole.service restarts when the
      # rendered config changes.
      "C+ ${cfg.dataDir}/etc-dnsmasq.d/99-tailnet-magicdns.conf 0644 root root - ${tailnetDnsConf}"
      # Keep /run/pihole around so the dns-hosts.env file from
      # pihole-dns-hosts.service isn't wiped out from under podman-pihole by
      # systemd's default /run cleanup.
      "d /run/pihole 0755 root root -"
    ];

    systemd.services.podman-pihole.restartTriggers = [
      tailnetDnsConf
      (pkgs.writeText "pihole-proxy-hosts" (lib.concatStringsSep "\n" proxyHostnames))
    ];

    # When dnsTarget isn't pinned, discover the Pi's tailnet IP at runtime
    # and write the FTLCONF_dns_hosts entries to a tmpfile that the container
    # picks up via environmentFiles. Avoids hardcoding the Pi's IP anywhere.
    #
    # Caveat: this only re-renders on podman-pihole (re)start. If the Pi's
    # tailnet IP changes mid-uptime (re-auth, node reset, key rotation), the
    # rendered file stays stale until something restarts podman-pihole —
    # `systemctl restart podman-pihole` is enough. Not worth a path-watcher
    # or timer: Tailscale doesn't reassign IPs once a node is enrolled, so
    # in practice this only fires on a deliberate re-auth.
    systemd.services.pihole-dns-hosts =
      lib.mkIf (shouldServeProxyDns && !hasStaticDnsTarget) {
        description = "Render Pi-hole local A records from current tailscale IP";
        # requiredBy makes podman-pihole hard-depend on us (won't start if we
        # fail). RemainAfterExit=false (the default) means we go back to
        # "dead" after success, so the next podman-pihole start re-triggers
        # us and re-renders /run/pihole/dns-hosts.env.
        requiredBy = [ "podman-pihole.service" ];
        before = [ "podman-pihole.service" ];
        after = [ "tailscaled.service" ];
        path = [ pkgs.tailscale ];
        serviceConfig.Type = "oneshot";
        script = ''
          install -d -m 0755 /run/pihole
          for _ in $(seq 1 30); do
            ip=$(tailscale ip -4 2>/dev/null | head -n1) || ip=""
            [ -n "$ip" ] && break
            sleep 1
          done
          if [ -z "$ip" ]; then
            echo "tailscale never returned an IPv4 address" >&2
            exit 1
          fi
          umask 077
          entries=""
          for host in ${lib.escapeShellArgs proxyHostnames}; do
            [ -n "$entries" ] && entries+=";"
            entries+="$ip $host"
          done
          printf 'FTLCONF_dns_hosts=%s\n' "$entries" > /run/pihole/dns-hosts.env
        '';
      };

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
    };

    reverseProxy.services.pihole = {
      host = "pihole.home-server";
      upstream = "127.0.0.1:${toString cfg.adminPort}";
      # Pi-hole 6 returns 403 on /, the UI lives under /admin/.
      probePath = "/admin/";
    };

    dashboard.services.pihole = {
      group = "Network";
      name = "Pi-hole";
      href = "http://pihole.home-server/admin/";
      icon = "pi-hole.png";
      description = "DNS sinkhole";
      widget = {
        type = "pihole";
        url = "http://127.0.0.1:${toString cfg.adminPort}";
        version = 6;
        key = "{{HOMEPAGE_VAR_PIHOLE_API_KEY}}";
      };
    };

    # ─── Monitoring ───
    # Pi-hole exposes its own Prometheus exporter and a community Grafana
    # dashboard. The Mac's monitoring module aggregates these via piConfig,
    # so this is the only place that knows about pihole-flavored monitoring.
    services.prometheus.exporters.pihole = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 9617;
      piholeHostname = "127.0.0.1";
      piholePort = cfg.adminPort;
      # PIHOLE_PASSWORD comes from the env shim below.
    };

    # Translate the agenix-stored Pi-hole 6 admin password
    # (FTLCONF_webserver_api_password=…) into the PIHOLE_PASSWORD env var the
    # eko/pihole-exporter binary expects. Keeps us from re-keying secrets.
    systemd.services.pihole-exporter-env = {
      description = "Translate Pi-hole web password into PIHOLE_PASSWORD env";
      wantedBy = [ "prometheus-pihole-exporter.service" ];
      before = [ "prometheus-pihole-exporter.service" ];
      after = [ "agenix.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0755 /run/pihole-exporter
        # shellcheck disable=SC1090
        set -a; . ${config.age.secrets.pihole-webpassword.path}; set +a
        umask 077
        echo "PIHOLE_PASSWORD=$FTLCONF_webserver_api_password" > /run/pihole-exporter/env
      '';
    };

    systemd.services.prometheus-pihole-exporter.serviceConfig.EnvironmentFile =
      "/run/pihole-exporter/env";

    monitoring.exporters.pihole = { port = 9617; };
    monitoring.dashboards.pihole = {
      id = 10176;
      revision = 3;
      hash = "sha256-MB4J1WAqLlV2eMFG67sYUbhJk3g1LnfjU+iEWejgyKE=";
      # Dashboard 10176 was built against an older exporter that returned
      # percentages; eko/pihole-exporter on v6 returns raw daily counts, so
      # panels rendered as "17251 %". Switch the unit to "short" for any
      # panel whose query targets the raw counters (covers both Grafana 7+
      # fieldConfig.defaults.unit and legacy yaxes[].format).
      extraFilter = ''
        walk(
          if type == "object"
             and ((.targets // []) | any(
               .expr // "" |
               (test("\\bpihole_querytypes\\b") or
                (test("\\bpihole_forward_destinations\\b") and (test("response") | not)))
             ))
          then
              (.fieldConfig.defaults.unit = "short")
            | (if has("yaxes") then .yaxes |= map(.format = "short") else . end)
          else . end
        )
      '';
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.pihole = {
        image = "pihole/pihole:latest";
        autoStart = true;
        ports = [
          "53:53/tcp"
          "53:53/udp"
          "127.0.0.1:${toString cfg.adminPort}:80/tcp"
        ];
        volumes = [
          "${cfg.dataDir}/etc-pihole:/etc/pihole"
          "${cfg.dataDir}/etc-dnsmasq.d:/etc/dnsmasq.d"
        ];
        environment = {
          TZ = config.time.timeZone;
          FTLCONF_dns_upstreams = lib.concatStringsSep ";" cfg.upstreamDns;
          FTLCONF_dns_listeningMode = "all";
          # Pi-hole 6 ignores /etc/dnsmasq.d/*.conf unless this is on. Without
          # it our 99-tailnet-magicdns.conf forwarder is silently unread, and
          # *.<tailnet>.ts.net queries from the host return nothing → Caddy
          # can't resolve its hostname upstreams.
          FTLCONF_misc_etc_dnsmasq_d = "true";
        }
        // lib.optionalAttrs (shouldServeProxyDns && hasStaticDnsTarget) {
          FTLCONF_dns_hosts = dnsHostEntries proxy.dnsTarget;
        };
        environmentFiles = [ config.age.secrets.pihole-webpassword.path ]
          ++ lib.optional (shouldServeProxyDns && !hasStaticDnsTarget)
            "/run/pihole/dns-hosts.env";
        extraOptions = [
          "--cap-add=NET_ADMIN"
          # Place the container payload inside the podman-pihole.service cgroup
          # so cAdvisor's per-unit metrics reflect actual container resources.
          "--cgroups=split"
        ];
      };
    };
  };
}
