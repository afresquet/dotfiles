# Attic: a private Nix binary cache on the tailnet, for projects whose store
# paths mustn't go to a public cache. Hosts don't substitute from it; whatever
# pushes and pulls holds an `atticd-atticadm make-token` token.
{ self, ... }:
{
  flake.modules.nixos.attic =
    { lib, config, ... }:
    let
      port = 8199;
      storage = "/mnt/hdd/attic";
    in
    {
      imports = [ self.modules.nixos.caddy ];

      age.secrets.attic-server.file = ../../secrets/attic-server.age;

      services.atticd = {
        enable = true;
        environmentFile = config.age.secrets.attic-server.path;
        settings = {
          listen = "127.0.0.1:${toString port}";
          api-endpoint = "http://attic.home-server/";
          # Chunks on the HDD; the SQLite database stays in /var/lib/atticd.
          storage = {
            type = "local";
            path = storage;
          };
        };
      };

      # The module runs atticd as a DynamicUser, which only owns its
      # StateDirectory; a static user can own the storage on the HDD.
      users = {
        users.atticd = {
          isSystemUser = true;
          group = "atticd";
        };
        groups.atticd = { };
      };
      systemd = {
        services.atticd = {
          serviceConfig.DynamicUser = lib.mkForce false;
          # /mnt/hdd is `nofail`; without the disk, atticd would write chunks
          # into the empty mount point on the NVMe.
          unitConfig.RequiresMountsFor = [ storage ];
        };
        tmpfiles.rules = [ "d ${storage} 0750 atticd atticd -" ];
      };

      reverseProxy.services.attic = {
        host = "attic.home-server";
        upstream = "127.0.0.1:${toString port}";
      };
    };
}
