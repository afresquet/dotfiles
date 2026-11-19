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
      capped = lib.filterAttrs (_: c: c.maxSize != null) cfg.caches;
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
              maxSize = lib.mkOption {
                type = lib.types.nullOr lib.types.ints.positive;
                default = null;
                example = lib.literalExpression "5 * 1024 * 1024 * 1024";
                description = ''
                  Bytes the cache may take on disk. Past it, the paths pulled or
                  pushed least recently are evicted (checked hourly). `null` is
                  no limit.
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
        assertions = [
          {
            # Attic has no releases, and a schema migration can land in any
            # commit nixpkgs packages.
            assertion = capped == { } || atticd.package.version == "0-unstable-2025-09-24";
            message = "attic-server is now ${atticd.package.version}: check its server/src/database/migration for changes to the object, nar, chunkref or chunk tables (or to the GC in server/src/gc.rs), adjust the attic-evict SQL in modules/homelab/attic.nix if needed, then bump the version in this assertion.";
          }
        ];

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

          # Attic only collects by age, so the size cap is our own SQL against
          # its schema (server/src/database/entity), written for the
          # attic-server the assertion above pins. A NAR's size is that of its
          # compressed chunks; chunks shared between NARs count once per NAR,
          # so a cache ends up
          # somewhat under its cap rather than over. NARs are ranked by their
          # latest pull or push, newest first, and the cache's objects for
          # every NAR past the cap are deleted, as the age-based collection
          # does; the collector then removes the orphaned NARs and chunks.
          services.attic-evict = lib.mkIf (capped != { }) {
            after = [ "atticd.service" ];
            unitConfig.RequiresMountsFor = [ storage ];
            path = [
              pkgs.sqlite
              atticd.package
            ];
            # The collector loads the whole server config, token key included.
            serviceConfig = {
              Type = "oneshot";
              User = "atticd";
              Group = "atticd";
              EnvironmentFile = atticd.environmentFile;
            };
            script = ''
              set -euo pipefail
              sql() { sqlite3 -cmd '.timeout 30000' /var/lib/atticd/server.db "$@"; }
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (
                name: c:
                let
                  cache = "(SELECT id FROM cache WHERE name = '${lib.replaceStrings [ "'" ] [ "''" ] name}')";
                in
                ''
                  sql <<'SQL'
                  WITH nar_access AS (
                    SELECT nar_id, MAX(COALESCE(last_accessed_at, created_at)) AS accessed
                    FROM object WHERE cache_id = ${cache} GROUP BY nar_id
                  ), nar_size AS (
                    SELECT cr.nar_id, SUM(COALESCE(c.file_size, c.chunk_size)) AS size
                    FROM chunkref cr JOIN chunk c ON c.id = cr.chunk_id
                    WHERE cr.nar_id IN (SELECT nar_id FROM nar_access)
                    GROUP BY cr.nar_id
                  ), ranked AS (
                    SELECT a.nar_id, SUM(s.size) OVER (
                      ORDER BY a.accessed DESC, a.nar_id DESC ROWS UNBOUNDED PRECEDING
                    ) AS kept
                    FROM nar_access a JOIN nar_size s USING (nar_id)
                  )
                  DELETE FROM object WHERE cache_id = ${cache}
                    AND nar_id IN (SELECT nar_id FROM ranked WHERE kept > ${toString c.maxSize});
                  SELECT 'Evicted ' || changes() || ' paths from ${name}';
                  SQL
                ''
              ) capped
            )
            + ''
              # A collection deletes at most 500 chunk files (SQLite's variable
              # limit) and leaves the rest marked D for the next one. A file
              # that fails to delete stays D too, hence the bound.
              for _ in $(seq 100); do
                atticd -f ${serverConfig} --mode garbage-collector-once
                [ "$(sql "SELECT COUNT(*) FROM chunk WHERE state = 'D'")" -eq 0 ] && break
              done
            '';
          };
          timers.attic-evict = lib.mkIf (capped != { }) {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = "hourly";
              Persistent = true;
            };
          };
        };

        reverseProxy.services.attic = {
          host = "attic.home-server";
          upstream = "127.0.0.1:${toString port}";
        };
      };
    };
}
