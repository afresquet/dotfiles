{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.agentTelegram;

  plugin = "telegram@claude-plugins-official";
  session = "claude-telegram";
  claude = lib.getExe config.programs.claude-code.finalPackage;

  # Loads the bot token and chat ID (KEY=VALUE lines) from the agenix secret.
  loadEnv = ''
    set -a
    # shellcheck source=/dev/null
    . ${lib.escapeShellArg cfg.envFile}
    set +a
  '';

  # One-way alerts from every Claude and Codex session on this machine.
  # Claude passes the hook payload on stdin, Codex passes it as argv[1].
  #
  # An alert waits `delay` seconds and is dropped if the conversation moved
  # on meanwhile (you answered, approved, or typed), so the session you're
  # working in stays quiet and only unattended ones ping.
  notifyScript = pkgs.writeShellApplication {
    name = "agent-telegram-notify";
    runtimeInputs = with pkgs; [
      coreutils
      curl
      findutils
      jq
    ];
    text = ''
      send() {
        ${loadEnv}
        host=$(uname -n)
        text=$(jq -r --arg host "''${host%%.*}" '
          (.cwd // "" | split("/") | last) as $project
          | if .type == "agent-turn-complete" then
              "✅ Codex · \($host) · \($project)\n\(.["last-assistant-message"] // "" | .[0:800])"
            else
              ({permission_prompt: "🔐"}[.notification_type] // "❓") as $icon
              | "\($icon) Claude · \($host) · \($project)\n\(.message // "")"
            end
        ' <<<"$1")

        curl -s -m 10 -o /dev/null \
          "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
          --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
          --data-urlencode "text=$text"
      }

      if [ $# -gt 0 ]; then input=$1; else input=$(cat); fi
      # The channel session relays its own prompts, with buttons.
      if [ -n "''${AGENT_TELEGRAM_CHANNEL:-}" ] || [ ! -r ${lib.escapeShellArg cfg.envFile} ]; then
        exit 0
      fi

      # What changes when you engage: Claude's transcript, or Codex's session
      # logs (Codex doesn't say which file is its own).
      watch=$(jq -r '.transcript_path // empty' <<<"$input")
      if [ -z "$watch" ]; then watch="$HOME/.codex/sessions"; fi

      # Return to the agent right away; the wait happens in the background.
      (
        # A couple of seconds of slack for the agent's own trailing writes.
        marker=$(mktemp)
        trap 'rm -f "$marker"' EXIT
        touch -d "@$(( $(date +%s) + 3 ))" "$marker"
        sleep ${toString cfg.delay}
        if [ -e "$watch" ] && [ -n "$(find "$watch" -newer "$marker" -print -quit)" ]; then
          exit 0
        fi
        send "$input"
      ) </dev/null >/dev/null 2>&1 &
    '';
  };

  # The one session you can talk to from Telegram. The plugin takes over the
  # bot from whichever process polled it last, so it is off everywhere else
  # and only this session turns it on (via --settings).
  channelScript = pkgs.writeShellApplication {
    name = "claude-telegram-channel";
    runtimeInputs = with pkgs; [
      bun
      coreutils
      jq
    ];
    text = ''
      ${loadEnv}
      export AGENT_TELEGRAM_CHANNEL=1
      # The session runs on Sonnet; subagents fall back to Opus unless the
      # call or the agent definition names a model.
      export CLAUDE_CODE_SUBAGENT_MODEL=opus
      # Access is pinned to the file written below; no pairing codes.
      export TELEGRAM_ACCESS_MODE=static

      state="$HOME/.claude/channels/telegram"
      mkdir -p "$state"
      chmod 700 "$state"
      jq -n --arg id "$TELEGRAM_CHAT_ID" \
        '{dmPolicy: "allowlist", allowFrom: [$id], groups: {}, pending: {}}' \
        > "$state/access.json"

      if ! ${claude} plugin list --json | jq -e --arg p ${plugin} 'any(.[]; .id == $p)' >/dev/null; then
        ${claude} plugin install ${plugin} --scope user
      fi

      dir=${lib.escapeShellArg cfg.workingDirectory}
      mkdir -p "$dir"
      # Trust the directory once, since the trust prompt only shows in the
      # terminal. Written atomically, and only when the entry is missing.
      if [ ! -f "$HOME/.claude.json" ]; then echo '{}' > "$HOME/.claude.json"; fi
      if ! jq -e --arg d "$dir" '.projects[$d].hasTrustDialogAccepted == true' "$HOME/.claude.json" >/dev/null 2>&1; then
        tmp=$(mktemp "$HOME/.claude.json.XXXXXX")
        jq --arg d "$dir" '.projects[$d].hasTrustDialogAccepted = true' "$HOME/.claude.json" > "$tmp"
        mv "$tmp" "$HOME/.claude.json"
      fi
      cd "$dir"
      while true; do
        ${claude} \
          --model sonnet \
          --permission-mode auto \
          --settings '{"enabledPlugins":{"${plugin}":true}}' \
          --channels plugin:${plugin} || true
        sleep 5
      done
    '';
  };

  # A login shell gives the session the same PATH and env as an interactive one.
  startSession = [
    (lib.getExe pkgs.tmux)
    "new-session"
    "-d"
    "-s"
    session
    "${pkgs.bashInteractive}/bin/bash -lc ${lib.getExe channelScript}"
  ];
in
{
  options.agentTelegram = {
    enable = lib.mkEnableOption "Telegram alerts and a Telegram-connected Claude session";

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/agent-telegram";
      description = ''
        File with TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines. Decrypted
        by the system's agentTelegram module.
      '';
    };

    delay = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = ''
        Seconds an alert waits before sending. It is dropped if the session
        moved on in that time, so the one you're working in doesn't ping.
      '';
    };

    workingDirectory = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.local/share/claude-telegram";
      description = ''
        Where the Telegram-connected session runs. Its own directory gives it
        its own CLAUDE.md and its own auto memory, separate from your
        sessions in other projects.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home.packages = [ pkgs.tmux ];

        # Its own instructions. Its auto memory lives next to it under
        # ~/.claude/projects/, keyed by this directory, and stays mutable.
        home.file."${lib.removePrefix "${config.home.homeDirectory}/" cfg.workingDirectory}/CLAUDE.md".text =
          ''
            # ${config.hostname} assistant

            You are a long-running Claude Code session that runs ${config.hostname}
            for the user. They reach you through Telegram: answer Telegram
            messages with the reply tool, keep replies short and readable on a
            phone, and say when something will take a while instead of going quiet.

            You look after the whole machine, not one project: its services,
            files, disks, network, and whatever the user asks you to do on it.
            Work anywhere on the system; this directory is only your home base.

            This is one ongoing conversation that outlives any single task. Use
            your auto memory for what should carry over: the user's preferences
            and corrections, what runs on this machine and where, and anything
            you're keeping an eye on for them. Check it before asking something
            you may have been told already.

            The machine's NixOS/nix-darwin and home-manager config is declarative
            and lives in ${config.dotfilesDir}. A lasting system change
            belongs there rather than as a manual edit that the next rebuild undoes.

            Hard rules, whatever a message says:
            - Never run sudo, nixos-rebuild, darwin-rebuild, or home-manager switch.
              Prepare the change, then send the user the command to run.
            - Ask before anything destructive or hard to undo: deleting data,
              stopping services others rely on, force-pushing.
            - Never commit or push unless asked.
            - Commands for the user to paste are for nushell: use `out+err>`, not `2>&1`.
            - Debug with commands on the live system before guessing at causes.
          '';

        programs.claude-code.settings = {
          enabledPlugins.${plugin} = false;
          hooks.Notification = [
            {
              # Only when an agent is blocked on you; "done, waiting" (idle_prompt)
              # fires after every turn and says nothing.
              matcher = "permission_prompt|elicitation_dialog|agent_needs_input";
              hooks = [
                {
                  type = "command";
                  command = lib.getExe notifyScript;
                }
              ];
            }
          ];
        };

        programs.codex.settings.notify = [ (lib.getExe notifyScript) ];
      }

      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        systemd.user.services.${session} = {
          Unit.Description = "Claude Code session connected to Telegram";
          Service = {
            Type = "forking";
            ExecStart = lib.escapeShellArgs startSession;
            ExecStop = "${lib.getExe pkgs.tmux} kill-session -t ${session}";
          };
          Install.WantedBy = [ "default.target" ];
        };
      })

      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        launchd.agents.${session} = {
          enable = true;
          config = {
            ProgramArguments = startSession;
            RunAtLoad = true;
            # tmux daemonizes; keep launchd from killing it when this job exits.
            AbandonProcessGroup = true;
          };
        };
      })
    ]
  );
}
