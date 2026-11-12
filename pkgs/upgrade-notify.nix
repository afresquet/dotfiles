{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "upgrade-notify";
  runtimeInputs = with pkgs; [
    coreutils
    libnotify
    util-linux
  ];
  text = ''
    # Usage: upgrade-notify start|stop <title> <log command> [<finished body>]
    #
    # For a oneshot unit's ExecStartPre/ExecStopPost; systemd sets
    # SERVICE_RESULT for the latter. From a user unit it notifies directly.
    # From a system unit (root, outside any session) it delivers to
    # $NOTIFY_USER's session bus instead.
    phase=$1 title=$2 log=$3 finished=''${4:-}

    run=()
    if [ "$(id -u)" -eq 0 ]; then
      user=''${NOTIFY_USER:?NOTIFY_USER must be set when run as root}
      bus="/run/user/$(id -u "$user")/bus"
      # Nobody logged in (e.g. a catch-up run at boot): nothing to notify.
      [ -S "$bus" ] || exit 0
      run=(runuser -u "$user" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus")
    fi

    send() {
      "''${run[@]}" notify-send --app-name="$title" --icon=system-software-update "$@"
    }

    case "$phase" in
      start) send "$title started" ;;
      stop)
        # ExecStopPost also runs when ExecCondition skips the unit (the
        # auto-upgrade gates' "nothing new"); there was no start to report.
        if [ "''${SERVICE_RESULT:-}" = exec-condition ]; then
          exit 0
        elif [ "''${SERVICE_RESULT:-}" = success ]; then
          send "$title finished" "$finished"
        else
          send --urgency=critical "$title failed" "$log"
        fi
        ;;
      *)
        echo "usage: upgrade-notify start|stop <title> <log command> [<finished body>]" >&2
        exit 2
        ;;
    esac
  '';
}
