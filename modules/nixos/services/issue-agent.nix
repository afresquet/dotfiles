{
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.issueAgent;
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  # The agent and its webhook are home-manager's issueAgent (Claude Code only
  # comes from the home config here); this is what needs the system.
  options.issueAgent = {
    enable = lib.mkEnableOption "the GitHub token and webhook port for home-manager's issueAgent";

    secretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        agenix file with a GH_TOKEN= line: a fine-grained token for the
        dotfiles repo only, with read/write on contents, pull requests and
        issues. Decrypted to /run/agenix/github-agent, readable by the
        primary user only.
      '';
    };

    telegramSecretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        agenix file with TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines for
        the GitHub notifications bot (the one the Actions workflows message),
        so PRs arrive with the CI alerts rather than from this machine's own
        bot. Decrypted to /run/agenix/telegram-github.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9871;
      description = "The webhook port; must match home-manager's issueAgent.port.";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = ''
        The only interface the port is open on. Which tailnet devices may
        reach it is up to the Tailscale access rules (only tag:ci).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets.github-agent = {
      file = cfg.secretFile;
      owner = config.username;
      mode = "0400";
    };
    age.secrets.telegram-github = {
      file = cfg.telegramSecretFile;
      owner = config.username;
      mode = "0400";
    };

    # The agent is a systemd user service; without lingering it only runs
    # while the user is logged in.
    users.users.${config.username}.linger = true;

    networking.firewall.interfaces.${cfg.interface}.allowedTCPPorts = [ cfg.port ];
  };
}
