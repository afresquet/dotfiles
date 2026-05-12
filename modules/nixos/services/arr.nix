{
  lib,
  config,
  pkgs,
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

  # Per-app exportarr config. The 5 *arr apps that store their API key in
  # config.xml.
  # TODO: bazarr — uses a different config format (YAML, not XML), so it
  # needs its own key extractor before it can join arrExporters.
  monitoringEnabled = config.monitoring.enable or false;
  prowlarrUrl =
    if (config.vpn.enable or false)
    then "http://${config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress}:${toString apps.prowlarr}"
    else "http://127.0.0.1:${toString apps.prowlarr}";
  arrExporters = {
    radarr   = { port = 9707; configPath = "/var/lib/radarr/.config/Radarr/config.xml";    url = "http://127.0.0.1:${toString apps.radarr}"; };
    sonarr   = { port = 9708; configPath = "/var/lib/sonarr/.config/NzbDrone/config.xml";  url = "http://127.0.0.1:${toString apps.sonarr}"; };
    lidarr   = { port = 9709; configPath = "/var/lib/lidarr/.config/Lidarr/config.xml";    url = "http://127.0.0.1:${toString apps.lidarr}"; };
    readarr  = { port = 9710; configPath = "/var/lib/readarr/config.xml";                  url = "http://127.0.0.1:${toString apps.readarr}"; };
    prowlarr = { port = 9711; configPath = "/var/lib/private/prowlarr/config.xml";         url = prowlarrUrl; };
  };
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
          # Place the container payload inside the podman-byparr.service cgroup
          # so cAdvisor's per-unit metrics reflect actual container resources.
          "--cgroups=split"
        ];
      };
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

    dashboard.services =
      let
        appMeta = {
          radarr = { displayName = "Radarr"; description = "Movies"; widgetType = "radarr"; };
          sonarr = { displayName = "Sonarr"; description = "TV shows"; widgetType = "sonarr"; };
          lidarr = { displayName = "Lidarr"; description = "Music"; widgetType = "lidarr"; };
          readarr = { displayName = "Readarr"; description = "Books"; widgetType = "readarr"; };
          bazarr = { displayName = "Bazarr"; description = "Subtitles"; widgetType = "bazarr"; };
          prowlarr = { displayName = "Prowlarr"; description = "Indexer manager"; widgetType = "prowlarr"; };
          jellyseerr = { displayName = "Jellyseerr"; description = "Media requests"; widgetType = "jellyseerr"; };
        };
      in
      lib.mapAttrs (
        name: port:
        let
          meta = appMeta.${name};
          # Prowlarr is in the namespace, so homepage (on host) reaches it via
          # the bridge IP. Everything else is a host service.
          widgetHost =
            if (config.vpn.enable or false) && name == "prowlarr" then
              config.vpnNamespaces.${config.vpn.namespace}.namespaceAddress
            else
              "127.0.0.1";
        in
        {
          group = "Media";
          name = meta.displayName;
          href = "http://${name}.home-server/";
          icon = "${name}.png";
          description = meta.description;
          widget = {
            type = meta.widgetType;
            url = "http://${widgetHost}:${toString port}";
            key = "{{HOMEPAGE_VAR_${lib.toUpper name}_API_KEY}}";
          };
        }
      ) apps;

    # All systemd.services in this module are merged here so the dotted form
    # (foo.x = ...) and the dynamically-keyed mapAttrs' form can co-exist.
    systemd.services = lib.mkMerge [
      (lib.mkIf (config.vpn.enable or false) {
        # Tie podman-byparr's lifecycle to wg.service.
        podman-byparr = {
          after = [ "wg.service" ];
          bindsTo = [ "wg.service" ];
          partOf = [ "wg.service" ];
        };
        # Confine prowlarr (the only native service that touches public
        # indexer sites) to the VPN namespace. Byparr runs as a container
        # attached to the namespace via --network=ns:..., so it doesn't need
        # vpnConfinement.
        prowlarr.vpnConfinement = {
          enable = true;
          vpnNamespace = config.vpn.namespace;
        };
      })

      # Per-app key extractors for exportarr. requiredBy = hard dep,
      # RemainAfterExit defaults false → re-runs on each exporter start so a
      # re-keyed config.xml gets picked up.
      (lib.mkIf monitoringEnabled (
        lib.mapAttrs' (
          appName: app: lib.nameValuePair "exportarr-${appName}-key" {
            description = "Extract API key for ${appName} exportarr";
            requiredBy = [ "prometheus-exportarr-${appName}-exporter.service" ];
            before = [ "prometheus-exportarr-${appName}-exporter.service" ];
            after = [ "${appName}.service" ];
            serviceConfig.Type = "oneshot";
            script = ''
              install -d -m 0755 /run/exportarr
              for _ in $(seq 1 30); do
                [ -s "${app.configPath}" ] && break
                sleep 1
              done
              if [ ! -s "${app.configPath}" ]; then
                echo "${appName} config.xml not present at ${app.configPath}" >&2
                exit 1
              fi
              umask 077
              ${pkgs.gnugrep}/bin/grep -oP '(?<=<ApiKey>)[^<]+' "${app.configPath}" \
                > /run/exportarr/${appName}-key
            '';
          }
        ) arrExporters
      ))
    ];

    vpnNamespaces = lib.mkIf (config.vpn.enable or false) {
      ${config.vpn.namespace}.portMappings = [
        {
          from = 9696;
          to = 9696;
          protocol = "tcp";
        }
      ];
    };

    # ─── Monitoring (exportarr) ───
    # Per-app oneshots extract the API key from each *arr's config.xml at
    # service start, dropping it into /run/exportarr/<app>-key. The exporter
    # then loads it via systemd LoadCredential (apiKeyFile option). This avoids
    # a secret-per-app in agenix — the *arr apps already manage their keys.

    services.prometheus.exporters = lib.mkIf monitoringEnabled (
      lib.mapAttrs' (
        appName: app: lib.nameValuePair "exportarr-${appName}" {
          enable = true;
          listenAddress = "0.0.0.0";
          inherit (app) port url;
          apiKeyFile = "/run/exportarr/${appName}-key";
        }
      ) arrExporters
    );

    monitoring.exporters = lib.mkIf monitoringEnabled (
      lib.mapAttrs' (
        appName: app: lib.nameValuePair "exportarr-${appName}" { inherit (app) port; }
      ) arrExporters
    );

    monitoring.dashboards = lib.mkIf monitoringEnabled {
      # onedr0p/exportarr's bundled "all-in-one" dashboard for Prowlarr +
      # Radarr/Sonarr/Lidarr/Readarr (Sabnzbd panels stay empty since we
      # don't run it). Pinned by commit so future upstream changes don't
      # silently break the hash.
      exportarr = {
        url = "https://raw.githubusercontent.com/onedr0p/exportarr/86a455425ab5299a36b85c14d881c51b05aa2629/examples/grafana/dashboard2.json";
        hash = "sha256-sF5fUFPu6rdF/4HUY7efqayira8s3vStSxcXCs3x+Wk=";
      };
    };
  };
}
