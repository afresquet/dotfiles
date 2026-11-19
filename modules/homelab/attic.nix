# Attic: Nix binary caches on the tailnet, for projects whose store paths
# mustn't go to a public cache. The caches are declared in `attic.caches`;
# pushing, and pulling from a private one, takes an
# `atticd-atticadm make-token` token.
{ self, ... }:
{
  flake.modules.nixos.attic =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.attic;
      inherit (config.services) atticd;
      port = 8199;
      api = "http://127.0.0.1:${toString port}";
      storage = "/mnt/hdd/attic";
      # The module keeps its own config file internal; atticadm only needs the
      # same settings to sign tokens with the key from the environment file.
      serverConfig = (pkgs.formats.toml { }).generate "server.toml" atticd.settings;
      attic = lib.getExe' pkgs.attic-client "attic";
      atticadm = "${lib.getExe' atticd.package "atticadm"} -f ${serverConfig}";
    in
    {
      imports = [ self.modules.nixos.caddy ];

      options.attic.caches = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              public = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Whether anyone who can reach it pulls without a token.";
              };
              priority = lib.mkOption {
                type = lib.types.int;
                default = 41;
                description = "Substituter priority; lower wins (cache.nixos.org is 40).";
              };
              retention = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "30 days";
                description = ''
                  How long paths nobody pushes or pulls are kept. `null` is the
                  server's default, which keeps them forever.
                '';
              };
            };
          }
        );
        default = { };
        description = ''
          Caches to create and keep configured. A cache removed from here is
          left as it is, not destroyed. Its signing key is generated on
          creation: `attic cache info <server>:<name>` prints the public half.
        '';
      };

      config = {
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

          # Caches only exist in atticd's database, created through its API.
          # Runs again whenever `attic.caches` changes, with a token that
          # expires in minutes and can only manage those caches.
          services.attic-caches = lib.mkIf (cfg.caches != { }) {
            after = [ "atticd.service" ];
            requires = [ "atticd.service" ];
            wantedBy = [ "multi-user.target" ];
            environment.XDG_CONFIG_HOME = "/run/attic-caches";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              DynamicUser = true;
              RuntimeDirectory = "attic-caches";
              EnvironmentFile = atticd.environmentFile;
              TimeoutStartSec = "2min";
            };
            script = ''
              set -euo pipefail
              until ${lib.getExe pkgs.curl} -fsS -o /dev/null ${api}/; do sleep 1; done
              token=$(${atticadm} make-token --sub attic-caches --validity "10 minutes" ${
                lib.concatMapStringsSep " " (
                  name:
                  lib.concatMapStringsSep " " (perm: "--${perm} ${lib.escapeShellArg name}") [
                    "pull"
                    "create-cache"
                    "configure-cache"
                    "configure-cache-retention"
                  ]
                ) (lib.attrNames cfg.caches)
              })
              ${attic} login local ${api} "$token" >/dev/null
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (
                name: c:
                let
                  ref = lib.escapeShellArg "local:${name}";
                in
                ''
                  ${attic} cache info ${ref} >/dev/null 2>&1 || ${attic} cache create ${ref}
                  ${attic} cache configure ${ref} ${if c.public then "--public" else "--private"} \
                    --priority ${toString c.priority} ${
                      if c.retention == null then
                        "--reset-retention-period"
                      else
                        "--retention-period ${lib.escapeShellArg c.retention}"
                    }
                ''
              ) cfg.caches
            );
          };
        };

        reverseProxy.services.attic = {
          host = "attic.home-server";
          upstream = "127.0.0.1:${toString port}";
        };
      };
    };
}
