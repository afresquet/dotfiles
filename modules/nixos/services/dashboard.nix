{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.dashboard;

  groupOrder = [
    "Media"
    "Downloads"
    "Network"
    "System"
  ];

  servicesByGroup = lib.foldl' (
    acc: svc: acc // { ${svc.group} = (acc.${svc.group} or [ ]) ++ [ svc ]; }
  ) { } (lib.attrValues cfg.services);

  homepageServices = lib.concatMap (
    groupName:
    let
      entries = servicesByGroup.${groupName} or [ ];
    in
    lib.optional (entries != [ ]) {
      ${groupName} = map (svc: {
        ${svc.name} =
          {
            href = svc.href;
            icon = svc.icon;
            description = svc.description;
          }
          // lib.optionalAttrs (svc.widget != null) {
            inherit (svc) widget;
          };
      }) entries;
    }
  ) groupOrder;
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  options.dashboard = {
    enable = lib.mkEnableOption "Homepage dashboard" // {
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port homepage-dashboard listens on (host-local).";
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            group = lib.mkOption {
              type = lib.types.enum groupOrder;
              description = "Section the tile appears under.";
            };
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name shown on the tile.";
            };
            href = lib.mkOption {
              type = lib.types.str;
              description = "URL the tile links to.";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              description = "Icon name from dashboard-icons (e.g. \"jellyfin.png\").";
            };
            description = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            widget = lib.mkOption {
              type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
              default = null;
              description = ''
                Homepage widget config. Use the literal `{{HOMEPAGE_VAR_NAME}}`
                template syntax for secrets — they're substituted at runtime
                from the agenix-decrypted environmentFile.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        Dashboard tiles, keyed by an internal name. Service modules contribute
        their own entries; the dashboard module groups and renders them.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.homepage-api-keys.file = ../../../secrets/homepage-api-keys.age;
    # No owner/group — homepage-dashboard runs with DynamicUser=true so there's
    # no persistent service user to chown to. Default root:root 0400 works
    # because systemd reads EnvironmentFile= as root before switching uid.

    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.port;
      openFirewall = false;
      environmentFile = config.age.secrets.homepage-api-keys.path;
      allowedHosts = "home-server,dashboard.home-server";

      settings = {
        title = "Home Server";
        headerStyle = "boxed";
        theme = "dark";
        color = "slate";
        layout = {
          Media = {
            style = "row";
            columns = 4;
          };
          Downloads = {
            style = "row";
            columns = 2;
          };
          Network = {
            style = "row";
            columns = 2;
          };
          System = {
            style = "row";
            columns = 2;
          };
        };
      };

      bookmarks = [
        {
          Admin = [
            { "Tailscale" = [ { href = "https://login.tailscale.com/admin/machines"; icon = "tailscale.png"; } ]; }
            { "Mullvad" = [ { href = "https://mullvad.net/en/account"; icon = "mullvad.png"; } ]; }
            { "Livebox" = [ { href = "http://192.168.1.1"; icon = "mdi-router-wireless"; } ]; }
          ];
        }
      ];

      services = homepageServices;

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = [
              "/"
              "/mnt/hdd"
            ];
          };
        }
        {
          search = {
            provider = "brave";
            target = "_blank";
          };
        }
        {
          datetime = {
            format = {
              dateStyle = "long";
              timeStyle = "short";
              hour12 = false;
            };
          };
        }
      ];
    };

    reverseProxy.services.dashboard = {
      host = "dashboard.home-server";
      aliases = [ "home-server" ];
      upstream = "127.0.0.1:${toString cfg.port}";
    };
  };
}
