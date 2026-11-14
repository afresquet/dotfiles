{ inputs, ... }:
{
  flake.modules.nixos.vpn =
    {
      lib,
      config,
      options,
      ...
    }:
    let
      cfg = config.vpn;
      # Whether the monitoring aspect is on this host (it declares serverHost).
      monitoringEnabled = lib.hasAttrByPath [ "monitoring" "serverHost" ] options;
      exporterPort = 9586;

      # Hand-written dashboard, kept as a static JSON file so UI edits can be
      # round-tripped via `export-grafana-dashboard`. nixpkgs ships MindFlavor's
      # wireguard exporter (`wireguard_sent_bytes_total` / `_received_` /
      # `_latest_handshake_*`); the popular grafana.com dashboards (12177 etc.)
      # target mdlayher's exporter with completely different metric names.
      wireguardDashboardJson = ./monitoring/_dashboards/wireguard.json;
    in
    {
      key = "self.modules.nixos.vpn";
      imports = [
        inputs.vpn-confinement.nixosModules.default
        ./monitoring/_nixos-options.nix
      ];

      options.vpn = {

        namespace = lib.mkOption {
          type = lib.types.str;
          default = "wg";
          description = "Network namespace name. Service modules opting in reference this.";
        };
      };

      config = {
        age.secrets.mullvad-wg = {
          file = ../../secrets/mullvad-wg.age;
          # vpn-confinement reads the file at activation as root.
        };

        vpnNamespaces.${cfg.namespace} = {
          enable = true;
          wireguardConfigFile = config.age.secrets.mullvad-wg.path;
          allowedIngress = [
            "127.0.0.1/32"
          ];
          portMappings = lib.mkIf monitoringEnabled [
            # Expose the wireguard exporter on the host so the Mac can scrape it.
            # The exporter has to live inside the namespace because wg0 is here.
            {
              from = exporterPort;
              to = exporterPort;
              protocol = "tcp";
            }
          ];
        };

        # ─── Monitoring ───
        services.prometheus.exporters.wireguard = lib.mkIf monitoringEnabled {
          enable = true;
          listenAddress = "0.0.0.0";
          port = exporterPort;
          withRemoteIp = true;
          latestHandshakeDelay = true;
        };

        # The wireguard exporter has to see wg0, which only exists inside the
        # namespace. Confine the systemd unit there — same trick prowlarr uses.
        systemd.services.prometheus-wireguard-exporter.vpnConfinement = lib.mkIf monitoringEnabled {
          enable = true;
          vpnNamespace = cfg.namespace;
        };

        monitoring.exporters.wireguard = lib.mkIf monitoringEnabled {
          port = exporterPort;
        };

        monitoring.dashboards.wireguard = lib.mkIf monitoringEnabled {
          json = wireguardDashboardJson;
        };
      };
    };
}
