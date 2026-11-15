# Grafana alerts sent through the machine's Telegram bot: an integration of
# monitoring and agent-telegram, for the host that runs Grafana.
{ self, ... }:
{
  flake.modules.darwin.monitoring-telegram =
    { config, pkgs, ... }:
    {
      imports = with self.modules.darwin; [
        monitoring
        agent-telegram
      ];

      # The bot's TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines, decrypted a
      # second time for the grafana user (the first copy is the main user's).
      age.secrets.grafana-telegram = {
        file = config.agentTelegram.secretFile;
        owner = "grafana";
        mode = "0400";
      };

      monitoring = {
        grafanaEnvironmentFiles = [ config.age.secrets.grafana-telegram.path ];
        # Every alert goes to the bot; Grafana expands the ${...} from its
        # environment when it loads the file.
        grafanaAlerting.telegram = pkgs.writeText "telegram.yaml" (
          builtins.toJSON {
            apiVersion = 1;
            contactPoints = [
              {
                orgId = 1;
                name = "telegram";
                receivers = [
                  {
                    uid = "telegram";
                    type = "telegram";
                    settings = {
                      bottoken = "\${TELEGRAM_BOT_TOKEN}";
                      chatid = "\${TELEGRAM_CHAT_ID}";
                      parse_mode = "None";
                    };
                  }
                ];
              }
            ];
            policies = [
              {
                orgId = 1;
                receiver = "telegram";
                group_by = [
                  "grafana_folder"
                  "alertname"
                ];
              }
            ];
          }
        );
      };
    };
}
