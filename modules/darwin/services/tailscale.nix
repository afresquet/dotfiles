{ lib, config, pkgs, inputs, ... }:
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
    system.activationScripts.tailscaleUp.text = ''
      ${lib.getExe pkgs.tailscale} up \
        --auth-key=file:${config.age.secrets.tailscale-auth.path} \
        ${lib.escapeShellArgs cfg.extraUpFlags} \
        || true
    '';
  };
}
