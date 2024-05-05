{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.waybar;
in
{
  options = {
    waybar = {
      enable = lib.mkEnableOption "Waybar" // {
        default = true;
      };
      statsIcon = lib.mkOption {
        type = lib.types.str;
        default = "";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      settings.mainBar = {
        layer = "top";
        height = 30;
        spacing = 4;
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ ];
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
          sort-by = "id";
          format = "{icon}";
          format-icons = {
            discord = "";
            browser = "<span font='Font Awesome 6 Brands'></span>";
            file-manager = "";
            terminal = "";
            music = "";
            whatsapp = "";
            obsidian = "";
            _1password = "";
          };
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
        bluetooth =
          let
            bluetuith = lib.getExe pkgs.bluetuith;
            terminal = lib.getExe config.terminal;
          in
          {
            format = "{icon}";
            format-icons = {
              on = "";
              off = "󰂲";
              disabled = "󰂲";
              connected = "";
            };
            on-click = "${terminal} ${bluetuith}";
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
          format = cfg.statsIcon;
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
        pulseaudio =
          let
            pavucontrol = lib.getExe pkgs.pavucontrol;
          in
          {
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
        "custom/session" =
          let
            wlogout = lib.getExe pkgs.wlogout;
          in
          {
            format = "";
            on-click = wlogout;
          };
      };
      style = builtins.readFile ./style.css;
    };
  };
}
