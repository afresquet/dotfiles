{ lib, config, pkgs, ... }: {
  options = {
    waybar.enable = lib.mkEnableOption "Waybar";
  };

  config =
    let
      pavucontrol = "${pkgs.pavucontrol}/bin/pavucontrol";
      wlogout = "${pkgs.wlogout}/bin/wlogout";
    in
    {
      programs.waybar = {
        enable = config.waybar.enable;
        settings.mainBar = {
          layer = "top";
          height = 30;
          spacing = 4;
          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];
          modules-right = [
            "tray"
            "privacy"
            "pulseaudio"
            "network"
            "bluetooth"
            "backlight"
            "battery"
            "group/stats"
            "clock"
            "custom/session"
          ];
          "hyprland/workspaces" = {
            disable-scroll = true;
            warp-on-scroll = false;
            format = "{name}";
          };
          "hyprland/window" = {
            separate-outputs = true;
            rewrite = {
              ".* - ([a-zA-Z]*)" = "$1";
              "([a-zA-Z]*) - .*" = "$1";
            };
          };
          tray = {
            spacing = 10;
          };
          bluetooth = {
            format = "{icon}";
            format-icons = {
              on = "";
              off = "󰂲";
              disabled = "󰂲";
              connected = "";
            };
          };
          clock = {
            format = "{:%H:%M}";
            format-alt = "{:%A, %B %d, %Y %R}";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode-mon-col = 3;
              weeks-pos = "left";
              on-scroll = 1;
              format = {
                months = "<span color='#ffead3'><b>{}</b></span>";
                days = "<span color='#ecc6d9'><b>{}</b></span>";
                weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                today = "<span color='#ff6699'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              "on-click-right" = "mode";
              "on-scroll-up" = "shift_up";
              "on-scroll-down" = "shift_down";
            };
          };
          cpu = {
            format = "{usage}% ";
            interval = 1;
          };
          "custom/gpu" = {
            exec = "cat /sys/class/hwmon/hwmon0/device/gpu_busy_percent";
            format = "{}% ";
            interval = 1;
          };
          memory = {
            format = "{}% ";
            interval = 1;
          };
          temperature = {
            critical-threshold = 80;
            format = "{temperatureC}°C {icon}";
            format-critical = "TOO HOT {temperatureC}°C {icon}";
            format-icons = [
              ""
              ""
              ""
            ];
            interval = 1;
          };
          backlight = {
            format = "{percent}% {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
              ""
            ];
          };
          battery = {
            states = {
              warning = 30;
              critical = 15;
            };
            format = "{capacity}% {icon}";
            format-full = "{capacity}% {icon}";
            format-charging = "{capacity}% ";
            format-plugged = "{capacity}% ";
            format-alt = "{time} {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };
          disk = {
            format = "{percentage_used}% ";
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
              transition-duration = 500;
            };
          };
          "custom/stats-icon" = {
            format = if config.touchpad.enable then "" else "";
            tooltip = false;
          };
          network = {
            format = "{ifname}";
            format-wifi = "{signalStrength}% ";
            format-ethernet = "";
            format-linked = "No IP ⚠";
            format-disconnected = "Disconnected ⚠";
            tooltip-format = "{ipaddr}";
          };
          pulseaudio = {
            format = "{volume}% {icon} {format_source}";
            format-bluetooth = "{volume}% {icon} {format_source}";
            format-bluetooth-muted = " {icon} {format_source}";
            format-muted = " {format_source}";
            format-source = "{volume}% ";
            format-source-muted = "";
            format-icons = {
              headphone = "";
              hands-free = "";
              headset = "";
              phone = "";
              portable = "";
              car = "";
              default = [
                ""
                ""
                ""
              ];
            };
            on-click = pavucontrol;
          };
          privacy = {
            icon-size = 16;
          };
          "custom/session" = {
            format = "";
            on-click = wlogout;
          };
        };
        style = builtins.readFile ./style.css;
      };
    };
}