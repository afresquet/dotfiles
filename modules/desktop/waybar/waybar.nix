{ self, ... }:
{
  flake.modules.homeManager.waybar =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.waybar;
      # The laptop's touchpad scrolls naturally, which makes Waybar's scroll
      # actions run backwards there. Waybar skips `reverse-scrolling` for mouse
      # wheels, so a mouse keeps the desktop's direction.
      naturalScroll = lib.optionalAttrs cfg.laptop { reverse-scrolling = true; };
    in
    {
      imports = with self.modules.homeManager; [
        ghostty
        swaync
        wlogout
      ];

      options.waybar = {
        statsIcon = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        laptop = lib.mkEnableOption "laptop-specific modules and behaviour";
      };

      config = {
        # Keep Stylix's palette and font, but style.css does all the layout.
        stylix.targets.waybar.addCss = false;

        programs.waybar = {
          enable = true;
          settings.mainBar = {
            layer = "top";
            height = 34;
            # Float the bar with the same gap Hyprland leaves around windows.
            margin-top = 8;
            margin-left = 8;
            margin-right = 8;
            spacing = 8;
            # The center is empty, so let the sides use its space; with a fixed
            # center the right side is capped at half the width and squeezes the
            # language label to "…" on the laptop.
            fixed-center = false;
            modules-right = [
              "group/status"
              "group/session"
            ];

            # Machine status, after the compositor's keyboard layout; the stats
            # drawer at the end opens to the left.
            "group/status" = {
              orientation = "horizontal";
              modules = [
                "pulseaudio"
                "pulseaudio#mic"
                "network"
                "bluetooth"
              ]
              ++ lib.optional cfg.laptop "backlight"
              ++ [
                "battery"
                "group/stats"
              ];
            };
            # Apps and time. The tray lives here because sharing a group with it
            # makes Waybar shorten the language label to "…".
            "group/session" = {
              orientation = "horizontal";
              modules = [
                "tray"
                "privacy"
              ]
              ++ [
                "custom/notification"
                "clock"
                "custom/session"
              ];
            };

            tray = {
              spacing = 10;
              icon-size = 16;
            };
            privacy.icon-size = 14;
            # Speaker: click to mute, right click for the mixer, scroll to change volume.
            pulseaudio =
              let
                pavucontrol = lib.getExe pkgs.pavucontrol;
                wpctl = lib.getExe' pkgs.wireplumber "wpctl";
              in
              {
                format = "{icon} {volume}%";
                format-bluetooth = "{icon}󰂯 {volume}%";
                format-bluetooth-muted = "󰝟󰂯";
                format-muted = "󰝟";
                tooltip-format = "{desc}: {volume}%\nClick: mute · right click: mixer";
                on-click = "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle";
                on-click-right = pavucontrol;
                format-icons = {
                  headphone = "󰋋";
                  hands-free = "󰋎";
                  headset = "󰋎";
                  phone = "󰏲";
                  portable = "󰏲";
                  car = "󰄋";
                  default = [
                    "󰕿"
                    "󰖀"
                    "󰕾"
                  ];
                };
              }
              # Touchpads send many small scroll deltas, so the laptop needs a
              # threshold or a swipe jumps the volume. Waybar applies the step and
              # threshold to every device, so keep the desktop's 1% step and set
              # the threshold just under one wheel notch: a mouse still moves 1%
              # per notch, and the touchpad needs about as much movement per 1% as
              # it did per 5% with a 5% step.
              // lib.optionalAttrs cfg.laptop { smooth-scrolling-threshold = 0.99; }
              // naturalScroll;
            # Microphone: click to mute, right click for the mixer's input tab,
            # scroll to change its volume.
            "pulseaudio#mic" =
              let
                pavucontrol = lib.getExe pkgs.pavucontrol;
                wpctl = lib.getExe' pkgs.wireplumber "wpctl";
              in
              {
                format = "{format_source}";
                format-muted = "{format_source}";
                format-bluetooth = "{format_source}";
                format-bluetooth-muted = "{format_source}";
                format-source = "󰍬";
                format-source-muted = "󰍭";
                tooltip-format = "Microphone: {source_volume}%\nClick: mute · right click: mixer";
                on-click = "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
                on-click-right = "${pavucontrol} --tab=4";
                on-scroll-up = "${wpctl} set-volume @DEFAULT_AUDIO_SOURCE@ 5%+ --limit 1.0";
                on-scroll-down = "${wpctl} set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
                smooth-scrolling-threshold = 5;
              }
              // naturalScroll;
            # Click opens nmtui in a terminal, like bluetuith for Bluetooth.
            network =
              let
                nmtui = lib.getExe' pkgs.networkmanager "nmtui";
                terminal = lib.getExe config.programs.ghostty.package;
              in
              {
                format = "󰛳 {ifname}";
                format-wifi = "{icon} {signalStrength}%";
                format-ethernet = "<span size='xx-large'>󰈀</span>";
                format-linked = "<span size='xx-large'>󰈀</span> No IP";
                format-disconnected = "󰤮";
                format-icons = [
                  "󰤯"
                  "󰤟"
                  "󰤢"
                  "󰤥"
                  "󰤨"
                ];
                tooltip-format = "{ifname}: {ipaddr}";
                tooltip-format-wifi = "{essid}: {ipaddr}";
                on-click = "${terminal} -e ${nmtui}";
              };
            bluetooth =
              let
                bluetuith = lib.getExe pkgs.bluetuith;
                terminal = lib.getExe config.programs.ghostty.package;
              in
              {
                format = "{icon}";
                format-icons = {
                  on = "󰂯";
                  off = "<span size='x-large'>󰂲</span>";
                  disabled = "<span size='x-large'>󰂲</span>";
                  connected = "<span size='x-large'>󰂱</span>";
                };
                tooltip-format-connected = "{device_enumerate}";
                tooltip-format-enumerate-connected = "{device_alias}";
                on-click = "${terminal} -e ${bluetuith}";
              };
            backlight = {
              format = "{icon} {percent}%";
              format-icons = [
                "󰃞"
                "󰃟"
                "󰃝"
                "󰃠"
              ];
            }
            // naturalScroll;
            battery = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{icon} {capacity}%";
              format-charging = "󰂄 {capacity}%";
              format-plugged = "󰚥 {capacity}%";
              format-alt = "{icon} {time}";
              format-icons = [
                "󰂎"
                "󰁺"
                "󰁼"
                "󰁾"
                "󰂀"
                "󰂂"
                "󰁹"
              ];
            };

            "group/stats" = {
              modules = [
                "custom/stats-icon"
                "temperature"
                "disk"
                "memory"
                "custom/gpu"
                "cpu"
              ];
              orientation = "horizontal";
              drawer = {
                transition-left-to-right = false;
                transition-duration = 300;
              };
            };
            "custom/stats-icon" = {
              format = cfg.statsIcon;
              tooltip = false;
            };
            temperature = {
              critical-threshold = 80;
              format = "{icon} {temperatureC}°C";
              format-icons = [
                "󱃃"
                "󰔏"
                "󱃂"
              ];
              interval = 3;
            };
            disk = {
              format = "󰋊 {percentage_used}%";
              interval = 30;
            };
            memory = {
              format = "󰍛 {}%";
              interval = 3;
            };
            # The card number isn't stable, so glob it. Prints nothing (and the
            # module hides) where there's no GPU load to read.
            "custom/gpu" = {
              exec = "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -n1";
              format = "󰢮 {}%";
              interval = 3;
            };
            cpu = {
              format = "󰻠 {usage}%";
              interval = 3;
            };

            clock =
              let
                c = config.lib.stylix.colors.withHashtag;
              in
              {
                format = "󰥔 {:%H:%M}";
                format-alt = "󰃭 {:%A, %B %d, %Y %R}";
                tooltip-format = "<tt><small>{calendar}</small></tt>";
                calendar = {
                  mode-mon-col = 3;
                  weeks-pos = "left";
                  on-scroll = 1;
                  format = {
                    months = "<span color='${c.base05}'><b>{}</b></span>";
                    days = "<span color='${c.base04}'>{}</span>";
                    weeks = "<span color='${c.base03}'>W{}</span>";
                    weekdays = "<span color='${c.base0D}'><b>{}</b></span>";
                    today = "<span color='${c.base0D}'><b><u>{}</u></b></span>";
                  };
                };
                actions = {
                  "on-click-right" = "mode";
                  "on-scroll-up" = "shift_up";
                  "on-scroll-down" = "shift_down";
                };
              }
              // naturalScroll;
            # Bell for SwayNotificationCenter: badge when something is waiting,
            # crossed out in do-not-disturb. Click: open, right click: toggle DND.
            "custom/notification" =
              let
                client = lib.getExe' config.services.swaync.package "swaync-client";
              in
              {
                exec = "${client} --subscribe-waybar";
                return-type = "json";
                format = "{icon}";
                format-icons = {
                  notification = "󱅫";
                  none = "󰂚";
                  dnd-notification = "󰂛";
                  dnd-none = "󰂛";
                  inhibited-notification = "󱅫";
                  inhibited-none = "󰂚";
                  dnd-inhibited-notification = "󰂛";
                  dnd-inhibited-none = "󰂛";
                };
                tooltip = false;
                escape = true;
                on-click = "${client} --toggle-panel --skip-wait";
                on-click-right = "${client} --toggle-dnd --skip-wait";
              };
            "custom/session" = {
              format = "󰐥";
              tooltip-format = "Power menu";
              on-click = lib.getExe config.wlogout.launcher;
            };
          };
          style = builtins.replaceStrings [ "@monospace@" ] [ config.stylix.fonts.monospace.name ] (
            builtins.readFile ./style.css
          );
        };

        services.playerctld.enable = true;
      };
    };
}
