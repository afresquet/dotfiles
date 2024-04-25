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
            "cpu"
            "memory"
            "disk"
            "temperature"
            "backlight"
            "battery"
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
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            format-alt = "{=%d-%m-%Y}";
          };
          cpu = {
            format = "{usage}% ";
          };
          memory = {
            format = "{}% ";
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
          network = {
            format = "{ifname}";
            format-wifi = "{signalStrength}% {icon}";
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
