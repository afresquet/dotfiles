{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.tailscale;
in
{
  imports = [
    ../../shared/services/tailscale.nix
    inputs.agenix.darwinModules.default
  ];

  config = lib.mkIf cfg.enable {
    age.secrets.tailscale-auth.file = ../../../secrets/tailscale-auth.age;

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
}
