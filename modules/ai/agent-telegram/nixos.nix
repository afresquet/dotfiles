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
    inputs.agenix.nixosModules.default
  ];

  config = lib.mkIf cfg.enable {
    age.secrets.agent-telegram = {
      file = cfg.secretFile;
      owner = config.username;
      mode = "0400";
    };

    # The Telegram session is a systemd user service; without lingering it
    # only runs while the user is logged in.
    users.users.${config.username}.linger = true;
  };
}
