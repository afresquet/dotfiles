{ pkgs, lib, ... }:
pkgs.writeShellApplication {
  name = "upgrade-notify";
  runtimeInputs =
    with pkgs;
    [
      coreutils
      curl
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      libnotify
      util-linux
    ];
  text = ''
    # Usage: upgrade-notify start|stop <title> <log command> [<finished body>]
    #
    # For a oneshot unit's ExecStartPre/ExecStopPost; systemd sets
    # SERVICE_RESULT for the latter (launchd scripts set it themselves).
    # Where it goes is up to the environment:
    # - NOTIFY_DESKTOP=1: a desktop notification. From a user unit directly;
    #   from a system unit (root, outside any session) on $NOTIFY_USER's
    #   session bus.
    # - TELEGRAM_ENV_FILE: a Telegram message through the bot in that file
    #   (TELEGRAM_BOT_TOKEN= and TELEGRAM_CHAT_ID= lines).
    phase=$1 title=$2 log=$3 finished=''${4:-}
    host=$(uname -n)
    host=''${host%%.*}

    desktop() {
      [ "''${NOTIFY_DESKTOP:-}" = 1 ] || return 0
      local run=()
      if [ "$(id -u)" -eq 0 ]; then
        local user bus
        user=''${NOTIFY_USER:?NOTIFY_USER must be set when run as root}
        bus="/run/user/$(id -u "$user")/bus"
        # Nobody logged in (e.g. a catch-up run at boot): nothing to notify.
        [ -S "$bus" ] || return 0
        run=(runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus")
      fi
      "''${run[@]}" notify-send --app-name="$title" --icon=system-software-update "$@"
    }

    telegram() {
      [ -n "''${TELEGRAM_ENV_FILE:-}" ] || return 0
      (
        set -a
        # shellcheck source=/dev/null
        . "$TELEGRAM_ENV_FILE"
        set +a
        curl -fsS -m 10 -o /dev/null \
          "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
          --data-urlencode "chat_id=$TELEGRAM_CHAT_ID" \
          --data-urlencode "text=$1"
      )
    }

    # One channel failing mustn't stop the other.
    case "$phase" in
      start)
        desktop "$title started" || true
        telegram "⬆️ $host: $title started" || true
        ;;
      stop)
        # ExecStopPost also runs when ExecCondition skips the unit (the
        # auto-upgrade gates' "nothing new"); there was no start to report.
        if [ "''${SERVICE_RESULT:-}" = exec-condition ]; then
          exit 0
        elif [ "''${SERVICE_RESULT:-}" = success ]; then
          desktop "$title finished" "$finished" || true
          telegram "✅ $host: $title finished''${finished:+ ($finished)}" || true
        else
          desktop --urgency=critical "$title failed" "$log" || true
          telegram "❌ $host: $title failed"$'\n'"Log: $log" || true
        fi
        ;;
      *)
        echo "usage: upgrade-notify start|stop <title> <log command> [<finished body>]" >&2
        exit 2
        ;;
    esac
  '';
}
