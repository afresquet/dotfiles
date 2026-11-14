{ self, ... }:
{
  flake.modules.homeManager.claude =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let

      # Usage and OAuth token caches live in a per-user directory rather than the
      # shared /tmp: $XDG_RUNTIME_DIR on Linux, the per-user $TMPDIR on macOS.
      # umask 077 covers the directory and every file written below.
      cacheSetup = ''
        umask 077
        CACHE_DIR="''${XDG_RUNTIME_DIR:-''${TMPDIR:-/tmp}}/claude-usage"
        mkdir -p "$CACHE_DIR"
        CACHE_FILE="$CACHE_DIR/usage"
      '';

      fetchUsageScript = pkgs.writeShellApplication {
        name = "claude-fetch-usage";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          curl
        ];
        runtimeEnv.LC_ALL = "C.UTF-8";
        text = ''
          ${cacheSetup}
          ATTEMPT_FILE="$CACHE_DIR/attempt"
          LOCK_DIR="$CACHE_DIR/lock"
          # Hooks call this on every tool use, from every session; only hit the
          # API once per minute, whether or not the last attempt succeeded.
          USAGE_TTL=60

          age() {
            echo $(( $(date -u +%s) - $(stat -c %Y "$1" 2>/dev/null || echo 0) ))
          }

          if [ -f "$ATTEMPT_FILE" ] && [ "$(age "$ATTEMPT_FILE")" -lt "$USAGE_TTL" ]; then
            exit 0
          fi

          if [ -d "$LOCK_DIR" ] && [ "$(age "$LOCK_DIR")" -ge 30 ]; then
            rmdir "$LOCK_DIR" 2>/dev/null || true
          fi
          mkdir "$LOCK_DIR" 2>/dev/null || exit 0
          trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
          touch "$ATTEMPT_FILE"
          rm -f "$CACHE_DIR/token"

          creds=""
          if [ -f "$HOME/.claude/.credentials.json" ]; then
            creds=$(cat "$HOME/.claude/.credentials.json")
          elif [ -x /usr/bin/security ]; then
            creds=$(/usr/bin/security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || true)
          fi
          token=$(jq -r '.claudeAiOauth.accessToken // empty' <<<"$creds" 2>/dev/null || true)
          if [ -z "$token" ]; then
            exit 0
          fi

          usage_json=$(curl -s -m 3 \
            -H "accept: application/json" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "authorization: Bearer $token" \
            -H "user-agent: claude-code/2.1.11" \
            "https://api.anthropic.com/oauth/usage" 2>/dev/null || true)

          if [ -z "$usage_json" ]; then
            exit 0
          fi

          five_h_raw=$(printf '%s' "$usage_json" | jq -r '.five_hour.utilization // empty' 2>/dev/null || true)
          seven_d_raw=$(printf '%s' "$usage_json" | jq -r '.seven_day.utilization // empty' 2>/dev/null || true)
          five_h_reset=$(printf '%s' "$usage_json" | jq -r '.five_hour.resets_at // ""' 2>/dev/null || true)
          seven_d_reset=$(printf '%s' "$usage_json" | jq -r '.seven_day.resets_at // ""' 2>/dev/null || true)
          fable=$(printf '%s' "$usage_json" | jq -r 'first(.limits[]? | select(.kind == "weekly_scoped" and .scope.model.display_name == "Fable") | .percent) // empty' 2>/dev/null || true)

          if [ -n "$five_h_raw" ] && [ -n "$seven_d_raw" ]; then
            five_h=$(printf "%.0f" "$five_h_raw")
            seven_d=$(printf "%.0f" "$seven_d_raw")
            printf '%s\n%s\n%s\n%s\n%s\n' "$five_h" "$seven_d" "$five_h_reset" "$seven_d_reset" "$fable" > "$CACHE_FILE.tmp"
            mv -f "$CACHE_FILE.tmp" "$CACHE_FILE"
          fi
        '';
      };

      statusLineScript = pkgs.writeShellApplication {
        name = "claude-statusline";
        runtimeInputs = with pkgs; [
          coreutils
          jq
          git
        ];
        runtimeEnv.LC_ALL = "C.UTF-8";
        text = ''
          input=$(cat)

          model=$(jq -r '.model.display_name // ""' <<<"$input")

          dir=$(jq -r '.workspace.current_dir // .cwd // ""' <<<"$input")
          dir_name=$(basename "$dir")

          branch=""
          if [ -n "$dir" ] && git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
            branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null \
              || git -C "$dir" rev-parse --short HEAD 2>/dev/null \
              || true)
          fi

          ${cacheSetup}
          five_h=""
          seven_d=""
          five_h_reset=""
          seven_d_reset=""
          fable=""

          if [ -f "$CACHE_FILE" ]; then
            { read -r five_h; read -r seven_d; read -r five_h_reset; read -r seven_d_reset; read -r fable; } <"$CACHE_FILE" || true
          else
            ${lib.getExe fetchUsageScript} >/dev/null 2>&1 &
          fi

          compute_delta() {
            local reset_epoch now_epoch diff days hours minutes
            reset_epoch=$(date -d "$1" +%s 2>/dev/null || true)
            if [ -z "$reset_epoch" ]; then return 0; fi
            now_epoch=$(date -u +%s)
            diff=$(( reset_epoch - now_epoch ))
            if [ "$diff" -le 0 ]; then echo "now"; return 0; fi
            days=$(( diff / 86400 ))
            hours=$(( (diff % 86400) / 3600 ))
            minutes=$(( (diff % 3600) / 60 ))
            if [ "$days" -gt 0 ]; then
              echo "''${days}d ''${hours}h"
            elif [ "$hours" -gt 0 ]; then
              echo "''${hours}h ''${minutes}m"
            else
              echo "''${minutes}m"
            fi
          }

          used=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
          ctx_str=""
          ctx_tokens_str=""
          if [ -n "$used" ]; then
            used_int=$(printf "%.0f" "$used")
            ctx_str="''${used_int}%"
            ctx_used=$(jq -r '(.context_window.current_usage.cache_read_input_tokens + .context_window.current_usage.cache_creation_input_tokens + .context_window.current_usage.input_tokens + .context_window.current_usage.output_tokens) // empty' <<<"$input" 2>/dev/null || true)
            ctx_total=$(jq -r '.context_window.context_window_size // empty' <<<"$input" 2>/dev/null || true)
            if [ -n "$ctx_used" ] && [ -n "$ctx_total" ]; then
              ctx_used_k=$(( ctx_used / 1000 ))
              ctx_total_k=$(( ctx_total / 1000 ))
              ctx_tokens_str="''${ctx_used_k}k/''${ctx_total_k}k"
            fi
          fi

          SEP="\033[90m • \033[0m"

          printf "\033[38;5;208m\033[1m%s\033[22m\033[0m" "$model"
          printf "\033[90m | \033[0m"
          printf "\033[1m\033[38;2;76;208;222m%s\033[22m\033[0m" "$dir_name"
          if [ -n "$branch" ]; then
            printf "%b" "$SEP"
            printf "\033[1m\033[38;2;192;103;222m%s\033[22m\033[0m" "$branch"
          fi

          printf "\n"
          if [ -n "$five_h" ]; then
            printf "\033[38;2;156;162;175m5h %s%%\033[0m" "$five_h"
            if [ -n "$five_h_reset" ]; then
              delta=$(compute_delta "$five_h_reset")
              if [ -n "$delta" ]; then
                printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$delta"
              fi
            fi
          fi
          if [ -n "$seven_d" ]; then
            if [ -n "$five_h" ]; then printf "%b" "$SEP"; fi
            printf "\033[38;2;156;162;175m7d %s%%\033[0m" "$seven_d"
            if [ -n "$seven_d_reset" ]; then
              delta=$(compute_delta "$seven_d_reset")
              if [ -n "$delta" ]; then
                printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$delta"
              fi
            fi
          fi
          if [ -n "$fable" ]; then
            if [ -n "$five_h" ] || [ -n "$seven_d" ]; then printf "%b" "$SEP"; fi
            printf "\033[38;2;156;162;175mfable %s%%\033[0m" "$fable"
          fi
          if [ -n "$ctx_str" ]; then
            printf "\033[90m | \033[0m"
            printf "\033[38;2;156;162;175mctx %s\033[0m" "$ctx_str"
            if [ -n "$ctx_tokens_str" ]; then
              printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$ctx_tokens_str"
            fi
          fi
        '';
      };

      direnvExportScript = pkgs.writeShellApplication {
        name = "claude-direnv-export";
        runtimeInputs = [
          pkgs.jq
          config.programs.direnv.package
        ];
        text = ''
          input=$(cat)
          dir=$(jq -r '.new_cwd // .cwd // empty' <<<"$input")
          if [ -n "''${CLAUDE_ENV_FILE:-}" ] && [ -n "$dir" ] && cd "$dir"; then
            direnv export bash >> "$CLAUDE_ENV_FILE" 2>/dev/null || true
          fi
        '';
      };

      direnvExportHook = {
        hooks = [
          {
            type = "command";
            command = lib.getExe direnvExportScript;
          }
        ];
      };

      fetchUsageHook = {
        matcher = "";
        hooks = [
          {
            type = "command";
            command = "${lib.getExe fetchUsageScript} >/dev/null 2>&1 &";
          }
        ];
      };
    in
    {
      imports = [ self.modules.homeManager.allowed-unfree ];

      config = {
        programs.claude-code = {
          enable = true;

          mutableSettings = true;

          settings = {
            theme = "dark";
            verbose = false;
            outputStyle = "Concise";
            agentPushNotifEnabled = true;
            attribution = {
              commit = "";
              pr = "";
            };
            statusLine = {
              type = "command";
              command = lib.getExe statusLineScript;
              padding = 0;
            };
            hooks = {
              PreToolUse = [ fetchUsageHook ];
              Stop = [ fetchUsageHook ];
              SessionStart = [ direnvExportHook ];
              CwdChanged = [ direnvExportHook ];
            };
          };
        };

        allowedUnfree = [ "claude-code" ];
      };
    };
}
