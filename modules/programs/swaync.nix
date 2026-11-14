{
  flake.modules.homeManager.swaync =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      client = lib.getExe' config.services.swaync.package "swaync-client";
      nmcli = lib.getExe' pkgs.networkmanager "nmcli";
      bluetoothctl = lib.getExe' pkgs.bluez "bluetoothctl";
      hyprsunset = lib.getExe pkgs.hyprsunset;

      # Quick toggles. Toggle buttons get the new state in SWAYNC_TOGGLE_STATE;
      # their update command echoes true or false when the panel opens.
      sh = name: text: "${pkgs.writeShellScript "cc-${name}" text}";
      toggle = name: label: command: update: {
        inherit label;
        type = "toggle";
        command = sh "${name}-set" command;
        update-command = sh "${name}-get" update;
      };
      # One-shot buttons close the panel first.
      button = name: label: command: {
        inherit label;
        command = sh name "${client} --close-panel --skip-wait\n${command}";
      };
      on = "[ \"$SWAYNC_TOGGLE_STATE\" = true ]";
    in
    {

      # Notifications plus a control center (SUPER + N or the Waybar bell) with a
      # media player, volume and do-not-disturb. Replaces mako.
      config = {
        services.swaync = {
          enable = true;
          settings = {
            positionX = "right";
            positionY = "top";
            layer = "overlay";
            control-center-layer = "top";
            control-center-margin-top = 8;
            control-center-margin-right = 8;
            control-center-margin-bottom = 8;
            control-center-width = 420;
            notification-window-width = 420;
            timeout = 8;
            timeout-low = 4;
            timeout-critical = 0;
            # A fixed height instead of stretching top to bottom; tall enough for a
            # few notifications under the widgets.
            fit-to-screen = false;
            control-center-height = 680;
            hide-on-clear = true;
            widgets = [
              "title"
              "dnd"
              "buttons-grid"
              "mpris"
              "volume"
              "notifications"
            ];
            widget-config = {
              title = {
                text = "Notifications";
                clear-all-button = true;
                button-text = "Clear";
              };
              dnd.text = "Do not disturb";
              mpris = {
                image-size = 72;
                # playerctld (enabled for Waybar) re-exports the active player as
                # its own MPRIS name, so every player would show up twice.
                blacklist = [ "playerctld" ];
              };
              volume.label = "󰕾";
              buttons-grid = {
                buttons-per-row = 6;
                actions = [
                  (toggle "wifi" "󰤨" "if ${on}; then ${nmcli} radio wifi on; else ${nmcli} radio wifi off; fi"
                    "[ \"$(${nmcli} radio wifi)\" = enabled ] && echo true || echo false"
                  )
                  (toggle "bluetooth" "󰂯"
                    "if ${on}; then ${bluetoothctl} power on; else ${bluetoothctl} power off; fi"
                    "${bluetoothctl} show | grep -q 'Powered: yes' && echo true || echo false"
                  )
                  # Night light: hyprsunset runs only while it's on.
                  (toggle "night-light" "󰖔"
                    "if ${on}; then setsid ${hyprsunset} -t 4500 >/dev/null 2>&1 </dev/null & else pkill -x hyprsunset; fi"
                    "pgrep -x hyprsunset >/dev/null && echo true || echo false"
                  )
                  (button "screenshot" "󰹑" "sleep 0.4\nSLURP_RECTS= ${lib.getExe pkgs.grimblast} copysave area")
                  (button "lock" "󰌾" "loginctl lock-session")
                ]
                ++ lib.optional config.programs.wlogout.enable (
                  button "power" "󰐥" (lib.getExe config.wlogout.launcher)
                );
              };
            };
          };

          # On top of Stylix's theme, matching rofi and Waybar: Hack font, dark
          # translucent panel (Hyprland blurs behind it), raised base01 cards,
          # 10px corners, blue accent.
          style = ''
            * {
              font-family: "${config.stylix.fonts.monospace.name}";
              font-size: 13px;
            }

            .control-center {
              /* Something lowers the panel's opacity otherwise. */
              opacity: 1;
              background: alpha(@base00, 0.88);
              border: 2px solid @base0D;
              border-radius: 12px;
              padding: 8px;
            }

            .widget-title > label {
              font-size: 15px;
              font-weight: bold;
            }

            .widget-title > button {
              padding: 2px 12px;
              border: none;
              border-radius: 8px;
              background: @base01;
              color: @base05;
            }

            .widget-title > button:hover {
              background: @base02;
            }

            .widget-dnd switch {
              border: none;
              border-radius: 999px;
              background: @base02;
            }

            .widget-dnd switch:checked {
              background: @base0D;
            }

            .widget-dnd switch slider {
              border-radius: 999px;
              background: @base05;
            }

            .widget-buttons-grid flowboxchild > button {
              min-height: 40px;
              border: none;
              border-radius: 10px;
              background: @base01;
              color: @base05;
            }

            .widget-buttons-grid flowboxchild > button label {
              font-size: 20px;
            }

            .widget-buttons-grid flowboxchild > button:hover {
              background: @base02;
            }

            .widget-buttons-grid flowboxchild > button.toggle:checked {
              background: @base0D;
              color: @base00;
            }

            .widget-title,
            .widget-dnd,
            .widget-buttons-grid,
            .widget-mpris,
            .widget-volume {
              margin: 4px 8px;
            }

            /* Media card: plain raised card instead of the blurred album art */
            .widget-mpris .widget-mpris-player {
              margin: 4px 0;
              border: none;
              box-shadow: none;
              border-radius: 10px;
              background: @base01;
            }

            .widget-mpris .widget-mpris-player .mpris-background {
              opacity: 0;
            }

            .widget-mpris .widget-mpris-player .mpris-overlay .widget-mpris-album-art {
              border-radius: 8px;
            }

            .widget-mpris .widget-mpris-player .mpris-overlay .widget-mpris-subtitle {
              color: @base04;
            }

            .widget-mpris > box > button {
              color: @base03;
            }

            trough {
              border: none;
              background: @base02;
            }

            trough highlight {
              background: @base0D;
            }

            /* Notifications: one urgency-colored border, no inner outline */
            .notification-content {
              border: none;
              background: transparent;
            }

            .notification-row .notification-background .notification {
              border-radius: 10px;
              background: @base01;
            }

            .floating-notifications .notification-row .notification-background .notification {
              background: @base00;
            }

            .notification.low {
              border-color: @base02;
            }

            .control-center .notification-row .notification-background,
            .control-center .notification-row .notification-background:hover {
              background: transparent;
            }

            /* No focus frame around the first notification */
            .control-center .notification-row:focus,
            .control-center .notification-row:focus-within,
            .control-center row:selected,
            .control-center row:focus {
              outline: none;
              box-shadow: none;
              background: transparent;
            }

            .control-center .control-center-list,
            .control-center scrolledwindow,
            .control-center viewport {
              border: none;
              background: transparent;
            }

            progress,
            progressbar {
              border: none;
            }

            .notification.normal progress {
              background: @base0D;
            }

            .close-button {
              background: @base02;
              color: @base05;
            }

            .close-button:hover {
              background: @base08;
              color: @base00;
            }

            .notification-action {
              border-radius: 8px;
              background: @base02;
            }

            .notification-action:hover {
              background: @base03;
            }
          '';
        };
      };
    };
}
