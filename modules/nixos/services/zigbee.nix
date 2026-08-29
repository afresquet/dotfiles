{
  lib,
  config,
  ...
}:
let
  cfg = config.zigbee;
in
{
  options.zigbee = {
    enable = lib.mkEnableOption "Zigbee2MQTT + Mosquitto stack" // {
      default = false;
    };

    device = lib.mkOption {
      type = lib.types.str;
      description = ''
        Stable path to the Zigbee coordinator. Use /dev/serial/by-id/usb-…
        rather than /dev/ttyUSB0 — kernel device numbers can renumber across
        reboots if any other USB serial device is present.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Zigbee2MQTT frontend port (host-local; proxied externally).";
    };

    mqttPort = lib.mkOption {
      type = lib.types.port;
      default = 1883;
      description = "Mosquitto MQTT port (loopback only).";
    };

    adapter = lib.mkOption {
      type = lib.types.enum [
        "zstack"
        "ember"
        "deconz"
        "zigate"
      ];
      default = "zstack";
      description = ''
        Z2M adapter driver. Sonoff Zigbee 3.0 USB Dongle Plus V1 (CC2652P) → zstack.
        Sonoff Plus V2 (EFR32MG21) → ember.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Loopback-only, anonymous. Single-host trust boundary — only Z2M (and
    # later HA's MQTT integration, both on this host) connect to the broker.
    # `acl = [ "topic readwrite #" ]` is required: the NixOS module always
    # emits `acl_file` for the listener even with zero users, and an empty
    # ACL file is deny-everything in mosquitto. Without this line every
    # anonymous publish (including Z2M's HA discovery) is silently dropped.
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          address = "127.0.0.1";
          port = cfg.mqttPort;
          omitPasswordAuth = true;
          settings.allow_anonymous = true;
          acl = [ "topic readwrite #" ];
        }
      ];
    };

    services.zigbee2mqtt = {
      enable = true;
      settings = {
        # MQTT discovery: Z2M publishes auto-config topics so paired devices
        # appear in HA automatically once HA's MQTT integration is added.
        # Nested key (not flat `homeassistant = true`) — the nixpkgs module
        # defines this option as an attrset (`homeassistant.enabled`) and the
        # two shapes can't be merged.
        homeassistant.enabled = true;
        # Flip on temporarily via the frontend when pairing a new device.
        permit_join = false;

        mqtt.server = "mqtt://127.0.0.1:${toString cfg.mqttPort}";

        serial = {
          port = cfg.device;
          adapter = cfg.adapter;
        };

        frontend.port = cfg.port;
        advanced.log_level = "info";
      };
    };

    # Avoid the connect-retry loop on boot — start Z2M only once the broker
    # socket is up.
    systemd.services.zigbee2mqtt = {
      after = [ "mosquitto.service" ];
      wants = [ "mosquitto.service" ];
    };

    reverseProxy.services.zigbee2mqtt = {
      host = "zigbee2mqtt.home-server";
      upstream = "127.0.0.1:${toString cfg.port}";
    };

    dashboard.services.zigbee2mqtt = {
      group = "System";
      name = "Zigbee2MQTT";
      href = "http://zigbee2mqtt.home-server/";
      icon = "zigbee2mqtt.png";
      description = "Zigbee gateway";
    };
  };
}
