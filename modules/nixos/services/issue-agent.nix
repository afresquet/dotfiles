{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.issueAgent;

  tailscale = lib.getExe config.services.tailscale.package;
  funnelFlags = [
    "--https=${toString cfg.funnelPort}"
    "--set-path=${cfg.funnelPath}"
  ];
in
{
  imports = [ inputs.agenix.nixosModules.default ];

  # The agent and its webhook listener are home-manager's issueAgent (Claude
  # Code only comes from the home config here); this is what needs the
  # system: secrets, lingering, and the Funnel that takes GitHub's webhook
  # deliveries to the listener.
  options.issueAgent = {
    enable = lib.mkEnableOption "the secrets and webhook Funnel for home-manager's issueAgent";

    secretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        agenix file with the private key (PEM) of the GitHub App the agent
        acts as. Decrypted to /run/agenix/github-agent, readable by the
        primary user only.
      '';
    };

    webhookSecretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        agenix file with the GitHub App's webhook secret, the raw value on one
        line. Deliveries not signed with it are rejected. Decrypted to
        /run/agenix/github-webhook.
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
      description = "The listener's port on localhost; must match home-manager's issueAgent.port.";
    };

    funnelPort = lib.mkOption {
      type = lib.types.enum [
        443
        8443
        10000
      ];
      # Not 443, so it can't collide with anything served on the tailnet.
      default = 8443;
      description = "Public HTTPS port of the Funnel (Funnel only allows these).";
    };

    funnelPath = lib.mkOption {
      type = lib.types.str;
      default = "/github-webhook";
      description = ''
        The webhook URL is https://<this machine's MagicDNS name>:<funnelPort><funnelPath>;
        only this path is exposed.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets = {
      github-agent = {
        file = cfg.secretFile;
        owner = config.username;
        mode = "0400";
      };
      github-webhook = {
        file = cfg.webhookSecretFile;
        owner = config.username;
        mode = "0400";
      };
      telegram-github = {
        file = cfg.telegramSecretFile;
        owner = config.username;
        mode = "0400";
      };
    };

    # The agent is a systemd user service; without lingering it only runs
    # while the user is logged in.
    users.users.${config.username}.linger = true;

    # GitHub's servers can't reach the tailnet, so Tailscale Funnel exposes
    # the one path publicly over HTTPS and proxies it to the listener on
    # localhost. The policy must grant `funnel` to this node (nodeAttrs) and
    # the tailnet needs HTTPS certificates enabled.
    systemd.services.issue-agent-funnel = {
      description = "Tailscale Funnel for the issue agent's GitHub webhook";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # tailscaled can be up before it's logged in; funnel needs that.
        ExecStartPre = pkgs.writeShellScript "issue-agent-funnel-wait" ''
          for _ in $(seq 60); do
            ${tailscale} status --peers=false >/dev/null 2>&1 && exit 0
            sleep 2
          done
          exit 1
        '';
        ExecStart = lib.escapeShellArgs (
          [
            tailscale
            "funnel"
            "--bg"
            "--yes"
          ]
          ++ funnelFlags
          ++ [ "http://127.0.0.1:${toString cfg.port}" ]
        );
        ExecStop = lib.escapeShellArgs (
          [
            tailscale
            "funnel"
          ]
          ++ funnelFlags
          ++ [ "off" ]
        );
        Restart = "on-failure";
        RestartSec = 30;
      };
    };
  };
}
