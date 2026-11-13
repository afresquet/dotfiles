{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.agentTelegram;
in
{
  imports = [
    ./common.nix
    inputs.agenix.darwinModules.default
  ];

  config = lib.mkIf cfg.enable {
    age.secrets.agent-telegram = {
      file = cfg.secretFile;
      owner = config.system.primaryUser;
      mode = "0400";
    };
  };
}
