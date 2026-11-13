{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.issueAgent;

  stateDir = "${config.xdg.stateHome}/issue-agent";
  claude = lib.getExe config.programs.claude-code.finalPackage;

  # What the agent may run. In print mode anything not allowed is denied
  # rather than asked, so this is the whole of it. It gets no GitHub
  # credentials: the wrapper fetches the issue and logs, and pushes and opens
  # the PR itself.
  allowedTools = [
    "Read"
    "Edit"
    "Write"
    "Glob"
    "Grep"
    "WebFetch"
    "WebSearch"
    "Bash(git status*)"
    "Bash(git diff*)"
    "Bash(git log*)"
    "Bash(git show*)"
    "Bash(git add*)"
    "Bash(git commit*)"
    "Bash(git restore*)"
    "Bash(git rm*)"
    "Bash(git mv*)"
    "Bash(nix eval *)"
    "Bash(nix fmt*)"
    "Bash(nix flake check --no-build*)"
    "Bash(nix flake metadata*)"
    "Bash(nix flake prefetch*)"
    "Bash(nix derivation show*)"
    "Bash(nix path-info*)"
    "Bash(jq *)"
    "Bash(rg *)"
    "Bash(ls *)"
    "Bash(diff *)"
  ];

  # A file rather than inline: shellcheck (which fails the script's build)
  # objects to its backticks inside a single-quoted string.
  prompt = pkgs.writeText "issue-agent-prompt.md" ''
    You are fixing a GitHub issue in the dotfiles repo checked out in the
    current directory, unattended. Nobody will answer questions: decide, or
    explain why you can't. Context (the issue, its comments, logs of the
    failed run it links, and any PR you opened for it before) is in
    @CONTEXT_FILE@; read it first.

    Follow AGENTS.md. In particular:
    - Verify by evaluating only: `nix fmt`, `nix flake check --no-build`, and
      `nix eval` of every configuration the change can reach. Never build:
      this is a Raspberry Pi, and Nix is configured here so that a build
      fails instead of running. CI builds the PR.
    - Don't run `nix flake update`; pinned versions are load-bearing.
    - Keep the change to what the issue needs.
    - Commit with a short lowercase summary (`vpn-confinement option
      renames`), no attribution trailers. If a PR for this issue already
      exists, you're on its branch: add commits on top.

    When you're done, write the PR title (one line, same style as the
    commit) to @OUT_DIR@/title and a short PR description in Markdown to
    @OUT_DIR@/body.md: what was wrong, what you changed, how you verified it.
    If the issue shouldn't or can't be fixed with a change here (e.g. an
    upstream outage, or a fix that needs a decision from the owner), commit
    nothing and write the reason to @OUT_DIR@/skip instead.
  '';

  # A request carries no data: it only starts the agent, which fetches the
  # issues from GitHub itself, so a forged one can at most cause an extra
  # check. A poke while the agent is running joins that run; anything it
  # misses, the hourly timer picks up.
  pokeHandler = pkgs.writeShellApplication {
    name = "issue-agent-poke";
    text = ''
      # Drain the request (headers end at a blank line); don't wait long.
      while IFS= read -r -t 2 line && [ -n "''${line%$'\r'}" ]; do :; done || true
      /run/current-system/sw/bin/systemctl --user start --no-block issue-agent.service
      printf 'HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\nConnection: close\r\n\r\n'
    '';
  };

  runtimeInputs = with pkgs; [
    coreutils
    curl
    gh
    git
    gnugrep
    gnused
    jq
  ];

  # Shared by both scripts.
  preamble = ''
    # nix comes from the system profile; claude shells out to it.
    export PATH="$PATH:/run/current-system/sw/bin"

    repo=${lib.escapeShellArg cfg.repo}
    state=${lib.escapeShellArg stateDir}
    clone="$state/repo"

    token=$(sed -n 's/^GH_TOKEN=//p' ${lib.escapeShellArg cfg.tokenFile})
    ghx() { GH_TOKEN=$token gh "$@"; }

    telegram() {
      (
        set -a
        # shellcheck source=/dev/null
        . ${lib.escapeShellArg cfg.telegramEnvFile}
        set +a
        curl -s -m 10 -o /dev/null \
          "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
          --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
          --data-urlencode "text=''${1:0:4000}"
      ) || echo "telegram notification failed" >&2
    }
  '';

  # One issue, given as `gh issue list --json` JSON. Its own process, so a
  # failure anywhere in it ends just this issue.
  oneScript = pkgs.writeShellApplication {
    name = "issue-agent-one";
    inherit runtimeInputs;
    text = ''
      ${preamble}
      issue=$1
      n=$(jq -r .number <<<"$issue")
      title=$(jq -r .title <<<"$issue")
      branch="agent/issue-$n"
      work="$state/work/$n"
      out="$state/out/$n"

      # Whatever an earlier, interrupted run left behind.
      git -C "$clone" worktree remove --force "$work" 2>/dev/null || true
      rm -rf "$work" "$out"
      git -C "$clone" worktree prune
      mkdir -p "$out" "$(dirname "$work")"
      trap 'git -C "$clone" worktree remove --force "$work" 2>/dev/null || true' EXIT

      if git -C "$clone" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        base="origin/$branch"
      else
        base="origin/main"
      fi
      git -C "$clone" worktree add --quiet --force -B "$branch" "$work" "$base"

      context="$out/context.md"
      {
        printf '# Issue #%s: %s\n\n%s\n' "$n" "$title" "$(jq -r .body <<<"$issue")"
        jq -r '.comments[] | "\n## Comment by \(.author.login)\n\n\(.body)"' <<<"$issue"
        # Logs of the runs the issue links to, failed steps only.
        jq -r '[.body, (.comments[].body)] | join("\n")' <<<"$issue" |
          { grep -oE 'actions/runs/[0-9]+' || true; } | sort -u | cut -d/ -f3 |
          while read -r run; do
            printf '\n## Failed steps of run %s\n\n```\n' "$run"
            ghx run view "$run" -R "$repo" --log-failed 2>&1 | tail -n 300 || true
            printf '```\n'
          done
        pr=$(ghx pr list -R "$repo" --head "$branch" --state open --json number,url,body \
          --jq '.[0] // empty')
        if [ -n "$pr" ]; then
          printf '\n## Your open PR for this issue\n\n%s\n\n%s\n' \
            "$(jq -r .url <<<"$pr")" "$(jq -r .body <<<"$pr")"
        fi
      } > "$context"

      prompt=$(cat ${prompt})
      prompt=''${prompt//@CONTEXT_FILE@/$context}
      prompt=''${prompt//@OUT_DIR@/$out}
      rc=0
      (
        cd "$work"
        # No local builds at all: a build fails instead of running, and
        # evaluation can't build through import-from-derivation.
        export NIX_CONFIG=$'max-jobs = 0\nallow-import-from-derivation = false'
        # Every event as it happens (text, thinking, tool calls and their
        # results), for issue-agent-watch; stderr apart so the JSON stays clean.
        timeout ${toString cfg.timeoutMinutes}m ${claude} -p "$prompt" \
          --model ${lib.escapeShellArg cfg.model} \
          --permission-mode acceptEdits \
          --add-dir "$out" \
          --output-format stream-json --verbose \
          --allowedTools ${lib.escapeShellArgs allowedTools} \
          < /dev/null > "$out/transcript.jsonl" 2> "$out/stderr.txt"
      ) || rc=$?

      ahead=$(git -C "$work" rev-list --count "$base..HEAD")
      if [ "$rc" -ne 0 ]; then
        telegram "⚠️ Issue agent failed on #$n $title (exit $rc). Log: issue-agent-watch $n"
      elif [ "$ahead" -gt 0 ] && [ -s "$out/title" ]; then
        # gh's credential helper hands git the token from GH_TOKEN.
        GH_TOKEN=$token git -C "$work" -c credential.helper= \
          -c credential.helper='!gh auth git-credential' \
          push --quiet --force-with-lease origin "HEAD:refs/heads/$branch"
        body=$(printf '%s\n\nFixes #%s\n' "$(cat "$out/body.md" 2>/dev/null)" "$n")
        existing=$(ghx pr list -R "$repo" --head "$branch" --state open --json url --jq '.[0].url // empty')
        summary=$(head -c 1500 "$out/body.md" 2>/dev/null || true)
        if [ -n "$existing" ]; then
          ghx pr edit "$existing" -R "$repo" --title "$(cat "$out/title")" --body "$body" >/dev/null
          telegram "🔧 Updated $existing for #$n $title"$'\n\n'"$summary"
        else
          url=$(ghx pr create -R "$repo" --base main --head "$branch" \
            --title "$(cat "$out/title")" --body "$body")
          telegram "🔧 $url fixes #$n $title"$'\n\n'"$summary"
        fi
      elif [ -s "$out/skip" ]; then
        telegram "🤷 Issue agent left #$n $title alone: $(head -c 1500 "$out/skip")"
      else
        telegram "⚠️ Issue agent finished #$n $title without a fix or a reason. Log: issue-agent-watch $n"
      fi
    '';
  };

  # `issue-agent-watch [issue]`: follow an agent run live (the latest one by
  # default), or replay a finished one.
  watchScript = pkgs.writeShellApplication {
    name = "issue-agent-watch";
    runtimeInputs = with pkgs; [
      coreutils
      jq
    ];
    text = ''
      out=${lib.escapeShellArg "${stateDir}/out"}
      if [ $# -gt 0 ]; then
        file="$out/$1/transcript.jsonl"
      else
        file=$(find "$out" -name transcript.jsonl -printf '%T@ %p\n' 2>/dev/null |
          sort -rn | head -n 1 | cut -d' ' -f2- || true)
      fi
      if [ -z "$file" ] || [ ! -e "$file" ]; then
        echo "no transcript yet" >&2
        exit 1
      fi
      echo "following $file (Ctrl-C to stop)"
      tail -n +1 -F "$file" | jq -rR --unbuffered '
        fromjson? |
        def short: tostring | gsub("\n"; " ") | .[0:200];
        if .type == "assistant" then
          .message.content[] |
          if .type == "text" then "💬 \(.text)"
          elif .type == "thinking" then "💭 \(.thinking)"
          elif .type == "tool_use" then
            "🔧 \(.name) \(.input | .command // .file_path // .pattern // .url // . | short)"
          else empty end
        elif .type == "user" then
          .message.content[]? | select(.type? == "tool_result") |
          "   ↳ \(.content | if type == "array" then map(.text? // "") | join(" ") else . end | short)"
        elif .type == "result" then
          "✅ \(.subtype) after \((.duration_ms // 0) / 60000 | floor) min, \(.num_turns // "?") turns"
        else empty end'
    '';
  };

  agentScript = pkgs.writeShellApplication {
    name = "issue-agent";
    inherit runtimeInputs;
    text = ''
      ${preamble}
      label=${lib.escapeShellArg cfg.label}
      mkdir -p "$state"
      handled="$state/handled.json"
      [ -f "$handled" ] || echo '{}' > "$handled"

      if [ ! -d "$clone/.git" ]; then
        git clone --quiet "https://github.com/$repo.git" "$clone"
        git -C "$clone" config user.name "home-server agent"
        git -C "$clone" config user.email "issue-agent@${config.hostname}"
      fi
      git -C "$clone" fetch --quiet --prune origin

      issues=$(ghx issue list -R "$repo" --label "$label" --state open --limit 20 \
        --json number,title,url,body,comments)
      jq -c '.[]' <<<"$issues" | while read -r issue; do
        n=$(jq -r .number <<<"$issue")
        # Rerun only when the issue's content changes (a new comment from CI
        # or from you), not on metadata like a PR linking to it.
        key=$(jq -r '[.body, (.comments[].body)] | join("\n---\n")' <<<"$issue" | sha256sum | cut -d' ' -f1)
        if [ "$(jq -r --arg n "$n" '.[$n] // ""' "$handled")" = "$key" ]; then
          continue
        fi
        echo "issue #$n: $(jq -r .title <<<"$issue")"
        if ! ${lib.getExe oneScript} "$issue"; then
          telegram "⚠️ Issue agent crashed on #$n $(jq -r .title <<<"$issue"); see journalctl --user -u issue-agent"
        fi
        # Handled whatever the outcome; it runs again once the issue changes.
        tmp=$(mktemp)
        jq --arg n "$n" --arg k "$key" '.[$n] = $k' "$handled" > "$tmp" && mv "$tmp" "$handled"
      done
    '';
  };
in
{
  options.issueAgent = {
    enable = lib.mkEnableOption "an agent that opens PRs for GitHub issues labelled for it";

    repo = lib.mkOption {
      type = lib.types.str;
      default = "afresquet/dotfiles";
      description = "GitHub repository (owner/name) whose issues it works on.";
    };

    label = lib.mkOption {
      type = lib.types.str;
      default = "agent";
      description = "Only open issues with this label are picked up.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      default = "opus";
    };

    timeoutMinutes = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
    };

    tokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/github-agent";
      description = "File with a GH_TOKEN= line, decrypted by the system's issueAgent module.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9871;
      description = ''
        Webhook port; must match the system's issueAgent.port, which opens
        it on the tailnet interface.
      '';
    };

    telegramEnvFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/telegram-github";
      description = ''
        File with TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines: the GitHub
        notifications bot, decrypted by the system's issueAgent module.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ watchScript ];

    systemd.user.services.issue-agent = {
      Unit = {
        Description = "Open PRs for GitHub issues labelled ${cfg.label}";
        # A home-manager switch mid-run would otherwise stop the unit and
        # kill the agent; the new version takes over from the next run.
        X-SwitchMethod = "keep-old";
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe agentScript;
      };
    };

    # The webhook. Its port is opened on the tailnet interface only by the
    # system's issueAgent module; Tailscale's access rules decide who on the
    # tailnet reaches it (only tag:ci).
    systemd.user.sockets.issue-agent-poke = {
      Unit.Description = "Webhook that makes the issue agent check for issues";
      Socket = {
        ListenStream = cfg.port;
        Accept = true;
        MaxConnectionsPerSource = 4;
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    systemd.user.services."issue-agent-poke@" = {
      Unit.Description = "Issue agent webhook request";
      Service = {
        ExecStart = lib.getExe pokeHandler;
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
        RuntimeMaxSec = 10;
      };
    };

    # Fallback for a poke that never arrived (the Pi was down, the Action
    # couldn't reach the tailnet, or the agent was already mid-run).
    systemd.user.timers.issue-agent = {
      Unit.Description = "Hourly check for issues labelled ${cfg.label}";
      Timer = {
        OnCalendar = "hourly";
        Persistent = true;
        RandomizedDelaySec = "5min";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
