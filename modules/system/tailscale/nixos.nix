{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.tailscale;
in
{
  imports = [
    ./common.nix
    inputs.agenix.nixosModules.default
  ];

  config = lib.mkIf cfg.enable {
    age.secrets.tailscale-auth.file = ../../../secrets/tailscale-auth.age;
    services.tailscale.authKeyFile = config.age.secrets.tailscale-auth.path;
    services.tailscale.extraUpFlags = cfg.extraUpFlags;
  };
}
