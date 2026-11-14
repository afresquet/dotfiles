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
    - Don't run `nix flake update`; pinned versions are load-bearing. For a
      failed flake update your branch already carries the new flake.lock
      (see "Your branch" in the context): keep it and make the code work
      with it, which is what AGENTS.md's overlay and assertion rules are for.
    - Keep the change to what the issue needs.
    - Commit with a short lowercase summary (`vpn-confinement option
      renames`), no attribution trailers. If a PR for this issue already
      exists, you're on its branch: add commits on top.
    - Feedback on that PR (comments, reviews, inline comments on lines) is
      in the context too. It comes from the owner: address all of it, and
      it wins over your earlier approach.

    When you're done, write the PR title (one line, same style as the
    commit) to @OUT_DIR@/title and a short PR description in Markdown to
    @OUT_DIR@/body.md: what was wrong, what you changed, how you verified it.
    If the issue shouldn't or can't be fixed with a change here (e.g. an
    upstream outage, or a fix that needs a decision from the owner), commit
    nothing and write the reason to @OUT_DIR@/skip instead.
  '';

  # One webhook delivery from the GitHub App, proxied here by the system's
  # Funnel. It's only acted on if signed with the webhook secret, and even
  # then it only starts the agent, which fetches the issues from GitHub
  # itself; the payload is never used. A delivery while the agent is running
  # joins that run; anything it misses, the hourly timer picks up.
  webhookHandler = pkgs.writeShellApplication {
    name = "issue-agent-webhook";
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    text = ''
      reply() {
        printf 'HTTP/1.1 %s\r\nContent-Length: 0\r\nConnection: close\r\n\r\n' "$1"
        exit 0
      }

      # Bash reads a socket a byte at a time, so after the headers the body
      # is still unread on stdin.
      IFS= read -r -t 5 _request || exit 0
      length="" signature="" event=""
      while IFS= read -r -t 5 line; do
        line=''${line%$'\r'}
        [ -n "$line" ] || break
        value=''${line#*:}
        value=''${value# }
        case "''${line%%:*}" in
          [Cc]ontent-[Ll]ength) length=$value ;;
          [Xx]-[Hh]ub-[Ss]ignature-256) signature=$value ;;
          [Xx]-[Gg]it[Hh]ub-[Ee]vent) event=$value ;;
        esac
      done

      case $length in "" | *[!0-9]*) reply "400 Bad Request" ;; esac
      [ "$length" -le 1048576 ] || reply "413 Content Too Large"
      body=$(mktemp)
      trap 'rm -f "$body"' EXIT
      timeout 5 head -c "$length" > "$body" || reply "400 Bad Request"
      [ "$(wc -c < "$body")" -eq "$length" ] || reply "400 Bad Request"

      # The secret is briefly on openssl's command line; only this user and
      # root can read another of its processes' arguments here.
      secret=$(cat ${lib.escapeShellArg cfg.webhookSecretFile})
      expected="sha256=$(openssl dgst -sha256 -hmac "$secret" -r < "$body" | cut -d' ' -f1)"
      [ "$signature" = "$expected" ] || reply "401 Unauthorized"

      case $event in
        issues | issue_comment | pull_request_review | pull_request_review_comment)
          /run/current-system/sw/bin/systemctl --user start --no-block issue-agent.service
          reply "202 Accepted"
          ;;
        *) reply "204 No Content" ;; # e.g. GitHub's ping when the webhook is set up
      esac
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
    openssl
  ];

  # Shared by both scripts.
  preamble = ''
    # nix comes from the system profile; claude shells out to it.
    export PATH="$PATH:/run/current-system/sw/bin"

    repo=${lib.escapeShellArg cfg.repo}
    label=${lib.escapeShellArg cfg.label}
    agent_marker='<!-- issue-agent -->'
    state=${lib.escapeShellArg stateDir}
    clone="$state/repo"

    # The agent acts as a GitHub App, not as you: a JWT signed with the app's
    # private key is exchanged for an installation token (valid for an hour)
    # scoped to what the app was granted on the repo it's installed on.
    app_jwt() {
      local now header payload sig
      b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
      now=$(date +%s)
      header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
      payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' \
        "$((now - 60))" "$((now + 540))" ${lib.escapeShellArg (toString cfg.appId)} | b64url)
      sig=$(printf '%s.%s' "$header" "$payload" |
        openssl dgst -sha256 -sign ${lib.escapeShellArg cfg.keyFile} | b64url)
      printf '%s.%s.%s' "$header" "$payload" "$sig"
    }
    app_api() {
      curl -fsS -H "Authorization: Bearer $(app_jwt)" -H "Accept: application/vnd.github+json" "$@"
    }
    mint_token() {
      local installation
      installation=$(app_api "https://api.github.com/repos/$repo/installation" | jq -r .id)
      app_api -X POST "https://api.github.com/app/installations/$installation/access_tokens" |
        jq -r .token
    }
    token=$(mint_token)
    if [ -z "$token" ] || [ "$token" = null ]; then
      echo "couldn't get a token for the GitHub App" >&2
      exit 1
    fi
    ghx() { GH_TOKEN=$token gh "$@"; }

    # The open agent PR for issue $1, if any.
    agent_pr() {
      ghx pr list -R "$repo" --head "agent/issue-$1" --state open --json number --jq '.[0].number // empty'
    }

    # Everything said on PR $1 as Markdown: conversation, review summaries
    # and inline comments on lines. Not the PR body, which the agent writes.
    pr_feedback() {
      ghx pr view "$1" -R "$repo" --json comments,reviews --jq '
        (.comments[] | "\n### Comment by \(.author.login)\n\n\(.body)"),
        (.reviews[] | select(.body != "") | "\n### Review by \(.author.login) (\(.state))\n\n\(.body)")'
      ghx api "repos/$repo/pulls/$1/comments" --paginate --jq '.[] |
        "\n### \(.user.login) on \(.path) line \(.line // .original_line)\n\n\(.body)"'
    }

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

      # A failed flake update leaves its candidate lock on a branch and marks
      # the issue; the fix goes on top of that lock, not main's.
      candidate=""
      if jq -r '[.body, (.comments[].body)] | join("\n")' <<<"$issue" |
        grep -q '<!-- agent-base: flake-update -->' &&
        git -C "$clone" rev-parse --verify --quiet origin/flake-update >/dev/null; then
        candidate=origin/flake-update
      fi
      restarted=""
      if git -C "$clone" rev-parse --verify --quiet "origin/$branch" >/dev/null; then
        base="origin/$branch"
        # A newer candidate (the update was rerun) that the branch doesn't
        # have: start over from it; the push replaces the branch.
        if [ -n "$candidate" ] && ! git -C "$clone" merge-base --is-ancestor "$candidate" "$base"; then
          base=$candidate
          restarted=1
        fi
      elif [ -n "$candidate" ]; then
        base=$candidate
      else
        base="origin/main"
      fi
      git -C "$clone" worktree add --quiet --force -B "$branch" "$work" "$base"

      context="$out/context.md"
      {
        printf '# Issue #%s: %s\n\n%s\n' "$n" "$title" "$(jq -r .body <<<"$issue")"
        if [ -n "$candidate" ]; then
          printf '\n## Your branch\n\n%s\n' "It starts from the failed update's flake.lock (the \`flake-update\` branch), so you are working against the inputs that failed. Keep that lock; fix the code on top of it."
          if [ -n "$restarted" ]; then
            printf 'The update was rerun with a newer lock since your PR, so the branch starts over from it: redo your fix (your PR below shows what it was).\n'
          fi
        fi
        jq -r '.comments[] | "\n## Comment by \(.author.login)\n\n\(.body)"' <<<"$issue"
        # Logs of the runs the issue links to, failed steps only.
        jq -r '[.body, (.comments[].body)] | join("\n")' <<<"$issue" |
          { grep -oE 'actions/runs/[0-9]+' || true; } | sort -u | cut -d/ -f3 |
          while read -r run; do
            printf '\n## Failed steps of run %s\n\n```\n' "$run"
            ghx run view "$run" -R "$repo" --log-failed 2>&1 | tail -n 300 || true
            printf '```\n'
          done
        pr=$(agent_pr "$n")
        if [ -n "$pr" ]; then
          printf '\n## Your open PR for this issue\n\n%s\n' \
            "$(ghx pr view "$pr" -R "$repo" --json url,body --jq '"\(.url)\n\n\(.body)"')"
          printf '\n## Feedback on your PR\n'
          pr_feedback "$pr"
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

      # Telegram carries links, not what the issue or PR already says, plus
      # what's only visible on this machine (failures, with how to look).
      issue_url=$(jq -r .url <<<"$issue")
      ahead=$(git -C "$work" rev-list --count "$base..HEAD")
      if [ "$rc" -ne 0 ]; then
        telegram "⚠️ Issue agent failed on #$n (exit $rc): $issue_url"$'\n'"Log: issue-agent-watch $n"
      elif [ "$ahead" -gt 0 ] && [ -s "$out/title" ]; then
        # A fresh token: the agent may have run for most of the last one's
        # hour. gh's credential helper hands git the token from GH_TOKEN.
        token=$(mint_token)
        GH_TOKEN=$token git -C "$work" -c credential.helper= \
          -c credential.helper='!gh auth git-credential' \
          push --quiet --force-with-lease origin "HEAD:refs/heads/$branch"
        body=$(printf '%s\n\nFixes #%s\n' "$(cat "$out/body.md" 2>/dev/null)" "$n")
        existing=$(ghx pr list -R "$repo" --head "$branch" --state open --json url --jq '.[0].url // empty')
        if [ -n "$existing" ]; then
          ghx pr edit "$existing" -R "$repo" --title "$(cat "$out/title")" --body "$body" \
            --add-label "$label" >/dev/null
          telegram "🔄 PR updated for #$n: $existing"
        else
          # Labelled so the agent's PRs are easy to tell apart.
          url=$(ghx pr create -R "$repo" --base main --head "$branch" \
            --title "$(cat "$out/title")" --body "$body" --label "$label")
          telegram "🔧 PR for #$n: $url"
        fi
      elif [ -s "$out/skip" ]; then
        # The reason goes on the issue. The marker keeps the agent's own
        # comments from counting as news that would make it run again.
        printf '%s\n\n%s\n' "$(cat "$out/skip")" "$agent_marker" |
          ghx issue comment "$n" -R "$repo" --body-file - >/dev/null
        telegram "🤷 Issue agent left #$n alone, reason on the issue: $issue_url"
      else
        telegram "⚠️ Issue agent finished #$n without a fix or a reason: $issue_url"$'\n'"Log: issue-agent-watch $n"
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
      mkdir -p "$state"
      handled="$state/handled.json"
      [ -f "$handled" ] || echo '{}' > "$handled"

      if [ ! -d "$clone/.git" ]; then
        git clone --quiet "https://github.com/$repo.git" "$clone"
      fi
      git -C "$clone" fetch --quiet --prune origin
      # Commit as the app's bot user, so GitHub shows its commits as the
      # app's (the noreply address is how GitHub links a bot account).
      slug=$(app_api https://api.github.com/app | jq -r .slug)
      bot_id=$(ghx api "users/$slug%5Bbot%5D" --jq .id)
      git -C "$clone" config user.name "''${slug}[bot]"
      git -C "$clone" config user.email "''${bot_id}+''${slug}[bot]@users.noreply.github.com"

      issues=$(ghx issue list -R "$repo" --label "$label" --state open --limit 20 \
        --json number,title,url,body,comments)
      jq -c '.[]' <<<"$issues" | while read -r issue; do
        n=$(jq -r .number <<<"$issue")
        # Rerun only when what was said changes: the issue (a new comment
        # from CI or from you) or the feedback on its PR. Not on metadata
        # like a PR linking to it, or the PR body the agent itself writes.
        # A GitHub hiccup here skips this issue until the next run rather
        # than ending the whole run.
        if ! pr=$(agent_pr "$n") || ! feedback=$(if [ -n "$pr" ]; then pr_feedback "$pr"; fi); then
          echo "couldn't read #$n's PR, trying again next run" >&2
          continue
        fi
        key=$({
          jq -r --arg m "$agent_marker" '[.body, (.comments[].body | select(contains($m) | not))] | join("\n---\n")' <<<"$issue"
          printf '%s' "$feedback"
        } | sha256sum | cut -d' ' -f1)
        if [ "$(jq -r --arg n "$n" '.[$n] // ""' "$handled")" = "$key" ]; then
          continue
        fi
        echo "issue #$n: $(jq -r .title <<<"$issue")"
        if ! ${lib.getExe oneScript} "$issue"; then
          telegram "⚠️ Issue agent crashed on #$n: $(jq -r .url <<<"$issue")"$'\n'"Log: journalctl --user -u issue-agent"
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

    appId = lib.mkOption {
      type = lib.types.ints.positive;
      description = ''
        ID of the GitHub App the agent acts as (on the app's settings page).
        It needs Contents, Issues and Pull requests read/write and Actions
        read, installed on the repo only, with its webhook pointing at the
        system's Funnel and subscribed to Issues, Issue comment, Pull request
        review and Pull request review comment.
      '';
    };

    keyFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/github-agent";
      description = "The app's private key (PEM), decrypted by the system's issueAgent module.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9871;
      description = ''
        The webhook listener's port on localhost; must match the system's
        issueAgent.port, where its Funnel forwards deliveries.
      '';
    };

    webhookSecretFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/github-webhook";
      description = "The GitHub App's webhook secret, decrypted by the system's issueAgent module.";
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

    # The webhook listener, on localhost only: the system's Funnel proxies
    # GitHub's deliveries to it. Every delivery arrives from 127.0.0.1, so
    # the cap is overall rather than per source.
    systemd.user.sockets.issue-agent-webhook = {
      Unit.Description = "GitHub App webhook that makes the issue agent check for issues";
      Socket = {
        ListenStream = "127.0.0.1:${toString cfg.port}";
        Accept = true;
        MaxConnections = 16;
      };
      Install.WantedBy = [ "sockets.target" ];
    };

    systemd.user.services."issue-agent-webhook@" = {
      Unit.Description = "Issue agent webhook delivery";
      Service = {
        ExecStart = lib.getExe webhookHandler;
        StandardInput = "socket";
        StandardOutput = "socket";
        StandardError = "journal";
        RuntimeMaxSec = 10;
      };
    };

    # Fallback for a delivery that never arrived (the Pi or the Funnel was
    # down) or arrived while the agent was already mid-run.
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
