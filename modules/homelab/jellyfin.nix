{ self, ... }:
{
  flake.modules.nixos.jellyfin =
    {
      lib,
      config,
      ...
    }:
    let
      cfg = config.jellyfin;
    in
    {
      imports = [
        self.modules.nixos.caddy
        self.modules.nixos.dashboard
      ];

      options.jellyfin = {

        port = lib.mkOption {
          type = lib.types.port;
          default = 8096;
          description = "Jellyfin HTTP port.";
        };
      };

      config = {
        users.groups.media = { };
        users.users.jellyfin.extraGroups = [ "media" ];

        services.jellyfin = {
          enable = true;
          openFirewall = true;
        };

        reverseProxy.services.jellyfin = {
          host = "jellyfin.home-server";
          upstream = "127.0.0.1:${toString cfg.port}";
        };

        dashboard.services.jellyfin = {
          group = "Media";
          name = "Jellyfin";
          href = "http://jellyfin.home-server/";
          icon = "jellyfin.png";
          description = "Media server";
          widget = {
            type = "jellyfin";
            url = "http://127.0.0.1:${toString cfg.port}";
            key = "{{HOMEPAGE_VAR_JELLYFIN_API_KEY}}";

            enableBlocks = true;
            enableNowPlaying = true;
          };
        };
      };
    };
}
