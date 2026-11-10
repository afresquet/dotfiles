{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.gitServer;
  stateDir = "/var/lib/soft-serve";
  sqlite = lib.getExe pkgs.sqlite;
in
{
  options.gitServer = {
    enable = lib.mkEnableOption "Soft Serve private git server" // {
      default = false;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 23231;
      description = "SSH port. Opened on the tailnet interface only.";
    };

    adminKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = config.users.users.${config.username}.openssh.authorizedKeys.keys;
      defaultText = lib.literalExpression "config.users.users.\${config.username}.openssh.authorizedKeys.keys";
      description = ''
        Public keys with admin access. Checked live against the config on
        every connection, so removing a key here revokes it. Every other key
        is anonymous, and anonymous access is pinned to no-access.
      '';
    };

    backup = {
      dir = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/hdd/backups/git-server";
        description = "Where daily snapshots of the server's data go.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "Snapshots older than this are pruned.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.soft-serve = {
      enable = true;
      settings = {
        name = "Home-Server";
        initial_admin_keys = cfg.adminKeys;
        ssh = {
          listen_addr = ":${toString cfg.port}";
          public_url = "ssh://home-server:${toString cfg.port}";
        };
        # SSH only: the git daemon and HTTP transports would be extra ways in.
        git.enabled = false;
        http.enabled = false;
      };
    };

    # Soft Serve seeds these as anon read-only and keyless allowed, and only
    # exposes them as runtime settings stored in its DB. Pin them on every
    # start (it reads them per request, so no restart is needed).
    # The nixpkgs unit sets ExecPaths=/var/lib/soft-serve/repos without
    # creating it, so the sandbox fails to set up (226/NAMESPACE) on a fresh
    # install. Newer nixpkgs adds it to StateDirectory like this.
    systemd.services.soft-serve.serviceConfig.StateDirectory =
      lib.mkForce "soft-serve soft-serve/repos";

    systemd.services.soft-serve.serviceConfig.ExecStartPost =
      pkgs.writeShellScript "soft-serve-lock-down" ''
        db=${stateDir}/soft-serve.db
        for _ in $(seq 50); do
          if ${sqlite} "$db" "SELECT 1 FROM settings WHERE key = 'anon_access'" 2>/dev/null | grep -q 1; then
            exec ${sqlite} -cmd ".timeout 5000" "$db" "
              UPDATE settings SET value = 'no-access', updated_at = CURRENT_TIMESTAMP WHERE key = 'anon_access';
              UPDATE settings SET value = 'false', updated_at = CURRENT_TIMESTAMP WHERE key = 'allow_keyless';
            "
          fi
          sleep 0.2
        done
        echo "soft-serve settings table never appeared" >&2
        exit 1
      '';

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.port ];

    # Daily snapshots on the HDD. Each one is a full tree, but unchanged files
    # are hardlinks to the previous snapshot, so they cost almost nothing.
    # Snapshots (not a mirror) so a deleted or force-pushed repo is recoverable.
    systemd.services.git-server-backup = {
      description = "Snapshot the git server to the HDD";
      unitConfig.RequiresMountsFor = [ cfg.backup.dir ];
      path = with pkgs; [
        coreutils
        rsync
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        # DynamicUser keeps the real data under /var/lib/private.
        src=/var/lib/private/soft-serve
        dest=${cfg.backup.dir}
        today=$(date +%F)
        mkdir -p "$dest"

        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        # Consistent copy of the live DB rather than whatever rsync catches.
        ${sqlite} "$src/soft-serve.db" ".backup '$tmp/soft-serve.db'"

        link=()
        if [ -d "$dest/latest" ]; then
          link=(--link-dest="$dest/latest")
        fi
        rsync -a --delete "''${link[@]}" \
          --exclude='soft-serve.db*' \
          "$src/" "$dest/$today.partial/"
        cp "$tmp/soft-serve.db" "$dest/$today.partial/"
        rm -rf "''${dest:?}/$today"
        mv "$dest/$today.partial" "$dest/$today"
        ln -sfn "$today" "$dest/latest"

        # By name: rsync -a copies the source's mtimes onto the snapshot dirs.
        cutoff=$(date -d "-${toString cfg.backup.keepDays} days" +%F)
        for snap in "$dest"/????-??-??; do
          if [ -d "$snap" ] && [[ "$(basename "$snap")" < "$cutoff" ]]; then
            rm -rf "$snap"
          fi
        done
      '';
    };

    systemd.timers.git-server-backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "04:00";
        Persistent = true;
        RandomizedDelaySec = "15m";
      };
    };
  };
}
