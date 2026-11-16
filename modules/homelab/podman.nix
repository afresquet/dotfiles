# Containers on podman. Every container follows its image tag: podman only
# pulls an image that is missing, so without auto-update `:latest` would stay
# at whatever the first pull got.
{
  flake.modules.nixos.podman =
    { lib, ... }:
    {
      options.virtualisation.oci-containers.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule { labels."io.containers.autoupdate" = lib.mkDefault "registry"; }
        );
      };

      config = {
        virtualisation = {
          podman = {
            enable = true;
            autoPrune.enable = true;
          };
          oci-containers.backend = "podman";
        };

        systemd.timers.podman-auto-update.wantedBy = [ "timers.target" ];
      };
    };
}
