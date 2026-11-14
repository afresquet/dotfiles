# Tailscale on every machine: the shared part (package, service, options) plus
# each platform's way of joining the tailnet with the auth key.
{ inputs, ... }:
let
  shared =
    {
      lib,
      pkgs,
      ...
    }:
    {
      options = {
        tailscale = {
          extraUpFlags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "--ssh" ];
            description = "Extra flags passed to `tailscale up`.";
          };
        };
      };

      config = {
        environment.systemPackages = [ pkgs.tailscale ];
        services.tailscale.enable = true;
      };
    };
in
{
  flake.modules.nixos.tailscale =
    {
      config,
      ...
    }:
    let
      cfg = config.tailscale;
    in
    {
      imports = [
        shared
        inputs.agenix.nixosModules.default
      ];

      config = {
        age.secrets.tailscale-auth.file = ../../secrets/tailscale-auth.age;
        services.tailscale.authKeyFile = config.age.secrets.tailscale-auth.path;
        services.tailscale.extraUpFlags = cfg.extraUpFlags;
      };
    };

  flake.modules.darwin.tailscale =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.tailscale;
    in
    {
      imports = [
        shared
        inputs.agenix.darwinModules.default
      ];

      config = {
        age.secrets.tailscale-auth.file = ../../secrets/tailscale-auth.age;

        # nix-darwin only runs its fixed set of activation slots, so this goes
        # into postActivation. Same states as NixOS's tailscaled-autoconnect: only
        # enroll when the daemon says it needs a login, never on a running node.
        system.activationScripts.postActivation.text = lib.mkAfter ''
          state=$(${lib.getExe pkgs.tailscale} status --json --peers=false 2>/dev/null \
            | ${lib.getExe pkgs.jq} -r .BackendState || true)
          case "$state" in
            NeedsLogin|NeedsMachineAuth|Stopped)
              echo "tailscale: state $state, sending auth key" >&2
              ${lib.getExe pkgs.tailscale} up \
                --auth-key=file:${config.age.secrets.tailscale-auth.path} \
                ${lib.escapeShellArgs cfg.extraUpFlags} \
                || true
              ;;
          esac
        '';
      };
    };
}
