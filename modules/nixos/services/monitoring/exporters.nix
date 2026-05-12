{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.monitoring;

  ports = {
    node = 9100;
    systemd = 9558;
    smartctl = 9633;
    process = 9256;
    blackbox = 9115;
    # cAdvisor's default 8080 collides with qBittorrent's web UI.
    cadvisor = 8085;
  };
in
{
  config = lib.mkIf cfg.enable {
    services.prometheus.exporters = {
      node = {
        enable = true;
        listenAddress = "0.0.0.0";
        port = ports.node;
        enabledCollectors = [
          "systemd"
          "processes"
          "logind"
          "interrupts"
          "ksmd"
          "mountstats"
          "network_route"
          "tcpstat"
          "thermal_zone"
        ];
      };

      systemd = {
        enable = true;
        listenAddress = "0.0.0.0";
        port = ports.systemd;
      };

      smartctl = {
        enable = true;
        listenAddress = "0.0.0.0";
        port = ports.smartctl;
      };

      process = {
        enable = true;
        listenAddress = "0.0.0.0";
        port = ports.process;
        settings.process_names = [
          {
            name = "{{.Comm}}";
            cmdline = [ ".+" ];
          }
        ];
      };

      blackbox = {
        enable = true;
        listenAddress = "0.0.0.0";
        port = ports.blackbox;
        configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON {
          modules = {
            http_2xx = {
              prober = "http";
              timeout = "5s";
              http = {
                preferred_ip_protocol = "ip4";
                valid_status_codes = [ ];
              };
            };
            icmp = {
              prober = "icmp";
              timeout = "5s";
              icmp.preferred_ip_protocol = "ip4";
            };
          };
        });
      };
    };

    services.cadvisor = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = ports.cadvisor;
    };

    monitoring.exporters = {
      node = { port = ports.node; };
      systemd = { port = ports.systemd; };
      smartctl = { port = ports.smartctl; };
      process = { port = ports.process; };
      cadvisor = {
        port = ports.cadvisor;
        # podman containers are launched with `--cgroups=split` (see each
        # oci-containers entry), which puts the container payload as a child
        # of `/system.slice/podman-<name>.service`. The parent cgroup then
        # aggregates total container resources, and this relabel turns the
        # cgroup id into a friendly `name=<container>` label.
        metricRelabelConfigs = [
          {
            source_labels = [ "id" ];
            regex = "/system\\.slice/podman-(.+)\\.service";
            target_label = "name";
            replacement = "\${1}";
          }
        ];
      };
      # Blackbox is included so the Mac knows its port; the Mac generates
      # the special "use blackbox to probe URLs" job structure separately.
      blackbox = { port = ports.blackbox; };
    };

    monitoring.dashboards = {
      node-exporter-full = {
        id = 1860;
        revision = 45;
        hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
      };
      cadvisor = {
        id = 14282;
        revision = 1;
        hash = "sha256-dqhaC4r4rXHCJpASt5y3EZXW00g5fhkQM+MgNcgX1c0=";
      };
      blackbox = {
        id = 13659;
        revision = 1;
        hash = "sha256-nnBFWFDAqKUqTOYxOrkRPlVla4ioQZ6rqEqakdzUj1Q=";
      };
    };
  };
}
