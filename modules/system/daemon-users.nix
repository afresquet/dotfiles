# Hidden macOS users and groups for launchd daemons, one per daemon, keyed by
# the name its launchd UserName/GroupName uses. Daemons that listen on the
# network (the monitoring stack, the GitHub agent) run as their own user, so a
# hole in one of them doesn't come with root and the Nix signing key the Pis
# trust.
{
  flake.modules.darwin.daemon-users =
    { lib, config, ... }:
    let
      cfg = config.daemonUsers;
    in
    {
      options.daemonUsers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              uid = lib.mkOption {
                type = lib.types.int;
                description = ''
                  uid and gid of the daemon's user and group. Below 500 so macOS
                  keeps it off the login window, like its own daemon accounts.
                '';
              };
              home = lib.mkOption {
                type = lib.types.str;
                default = "/var/empty";
                description = "The user's home. Add it to `dirs` too if it should be created.";
              };
              dirs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "Directories created at activation and owned by the daemon.";
              };
              logs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
                description = "The daemon's StandardOutPath/StandardErrorPath, owned by it.";
              };
            };
          }
        );
        default = { };
      };

      config = {
        users = {
          knownUsers = lib.attrNames cfg;
          knownGroups = lib.attrNames cfg;
          users = lib.mapAttrs (name: d: {
            inherit (d) uid home;
            gid = d.uid;
            description = name;
            shell = "/usr/bin/false";
            isHidden = true;
          }) cfg;
          groups = lib.mapAttrs (name: d: {
            gid = d.uid;
            description = name;
          }) cfg;
        };

        # Hooked into the wired-in `postActivation` slot because nix-darwin
        # doesn't reliably run custom slots; it runs after the users slot, so the
        # owners exist. Data written back when a daemon ran as root is handed
        # over once, when a directory isn't the daemon's yet. BSD stat by
        # path: GNU coreutils can come first on PATH, and its `-f` means
        # something else.
        system.activationScripts.postActivation.text = lib.mkAfter (
          lib.concatStrings (
            lib.mapAttrsToList (
              name: d:
              lib.concatMapStrings (dir: ''
                install -d -m 0755 -o ${name} -g ${name} ${dir}
                [ "$(/usr/bin/stat -f %u ${dir})" = ${toString d.uid} ] || chown -R ${name}:${name} ${dir}
              '') d.dirs
              + lib.concatMapStrings (log: ''
                touch ${log}
                chown ${name}:${name} ${log}
              '') d.logs
            ) cfg
          )
        );
      };
    };
}
