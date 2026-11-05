{ lib, ... }:
{
  options.agentTelegram = {
    enable = lib.mkEnableOption "the Telegram bot secret for agent alerts and the Telegram-connected Claude session";

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
