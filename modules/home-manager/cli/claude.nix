{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.claude;

  fetchUsageScript = pkgs.writeShellApplication {
    name = "claude-fetch-usage";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      curl
    ];
    runtimeEnv.LC_ALL = "C.UTF-8";
    text = ''
      CACHE_FILE="/tmp/.claude_usage_cache"
      TOKEN_CACHE="/tmp/.claude_token_cache"
      TOKEN_TTL=900

      token=""
      if [ -f "$TOKEN_CACHE" ]; then
        cache_age=$(( $(date -u +%s) - $(stat -c %Y "$TOKEN_CACHE" 2>/dev/null || echo 0) ))
        if [ "$cache_age" -lt "$TOKEN_TTL" ]; then
          token=$(cat "$TOKEN_CACHE" 2>/dev/null || true)
        fi
      fi

      if [ -z "$token" ]; then
        creds_file="$HOME/.claude/.credentials.json"
        if [ ! -f "$creds_file" ]; then
          exit 0
        fi
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null || true)
        if [ -z "$token" ]; then
          exit 0
        fi
        printf '%s' "$token" > "$TOKEN_CACHE"
        chmod 600 "$TOKEN_CACHE" 2>/dev/null || true
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

      if [ -n "$five_h_raw" ] && [ -n "$seven_d_raw" ]; then
        five_h=$(printf "%.0f" "$five_h_raw")
        seven_d=$(printf "%.0f" "$seven_d_raw")
        printf '%s\n%s\n%s\n%s\n' "$five_h" "$seven_d" "$five_h_reset" "$seven_d_reset" > "$CACHE_FILE"
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

      CACHE_FILE="/tmp/.claude_usage_cache"
      five_h=""
      seven_d=""
      five_h_reset=""
      seven_d_reset=""

      if [ -f "$CACHE_FILE" ]; then
        five_h=$(sed -n '1p' "$CACHE_FILE")
        seven_d=$(sed -n '2p' "$CACHE_FILE")
        five_h_reset=$(sed -n '3p' "$CACHE_FILE")
        seven_d_reset=$(sed -n '4p' "$CACHE_FILE")
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
      if [ -n "$ctx_str" ]; then
        printf "\033[90m | \033[0m"
        printf "\033[38;2;156;162;175mctx %s\033[0m" "$ctx_str"
        if [ -n "$ctx_tokens_str" ]; then
          printf " \033[2m\033[38;2;156;162;175m(%s)\033[0m" "$ctx_tokens_str"
        fi
      fi
    '';
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
  options = {
    claude.enable = lib.mkEnableOption "Claude" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = {
      enable = true;

      settings = {
        theme = "dark";
        agentPushNotifEnabled = true;
        statusLine = {
          type = "command";
          command = lib.getExe statusLineScript;
          padding = 0;
        };
        hooks = {
          PreToolUse = [ fetchUsageHook ];
          Stop = [ fetchUsageHook ];
        };
      };
    };

    allowedUnfree = [ "claude-code" ];
  };
}
