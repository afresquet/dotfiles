{ lib, ... }:
{
  # `agentTelegram.enable` is a host setting (hosts/settings.nix), shared
  # with the home config.
  options.agentTelegram = {
    secretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        agenix file with TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines, one
        bot per machine. Decrypted to /run/agenix/agent-telegram, readable by
        the primary user only (home-manager's agentTelegram reads it there).
      '';
    };
  };
}
