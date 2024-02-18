{ pkgs, ... }:
let
  pavucontrol = "${pkgs.pavucontrol}/bin/pavucontrol";
  wlogout = "${pkgs.wlogout}/bin/wlogout -b 2";
in {
  programs.waybar.enable = true;
  programs.waybar.settings.mainBar = {
    layer = "top";
    margin = "8 8 0 8";
    modules-left = [
      "clock"
    ];
    modules-center = [
      "hyprland/workspaces"
    ];
    modules-right = [
      "tray"
      "pulseaudio"
      "bluetooth"
      "network"
      "custom/session"
    ];
    "hyprland/window" = {
      format = "{title}";
      max-length = 333;
      seperate-outputs = true;
    };
    clock = {
      format = "<span foreground='#e6b673'> </span><span>{:%I:%M %a %d}</span>";
      tooltip-format = "{calendar}";
      calendar = {
        mode = "month";
        mode-mon-col = 3;
        on-scroll = 1;
        on-click-right = "mode";
        format = {
          months = "<span color='#ffead3'><b>{}</b></span>";
          days = "<span color='#ecc6d9'><b>{}</b></span>";
          weeks = "<span color='#99ffdd'><b>{%W}</b></span>";
          weekdays = "<span color='#ffcc66'><b>{}</b></span>";
          today = "<span color='#ff6699'><b>{}</b></span>";
        };
      };
      actions = {
        on-click-middle = "mode";
        on-click-right = "shift_up";
        on-click = "shift_down";
      };
    };
    "hyprland/workspaces" = {
      format = "{name}";
      format-icons = {
        default = "";
        urgent = "";
        active = "󱓻";
        empty = "";
      };
      active-only = false;
      sort-by-number = true;
      on-click = "activate";
      all-outputs = false;
    };
    network = {
      format = "󰤭 Off";
      format-wifi = "{essid} ({signalStrength}%)";
      format-ethernet = "<span foreground='#b48ead'>󰈀</span>";
      format-disconnected = "󰤭 Disconnected";
      tooltip-format = "{ifname} via {gwaddr} ";
      tooltip-format-wifi = "{essid}({signalStrength}%)  ";
      tooltip-format-ethernet = "󰈀 {ifname}";
      tooltip-format-disconnected = "Disconnected";
    };
    pulseaudio = {
      format = "<span foreground='#f26d78'>{icon}</span> {volume}%  {format_source}";
      format-bluetooth = "<span foreground='#95e6cb'>{icon}</span> {volume}%  {format_source}";
      format-bluetooth-muted = "<span foreground='#95e6cb'>󰖁</span>  {format_source}";
      format-muted = "<span foreground='#F38BA8'>󰖁</span>  {format_source}";
      format-source = "<span foreground='#fab387'></span> {volume}%";
      format-source-muted = "<span foreground='#F38BA8'></span>";
      format-icons = {
        headphone = "";
        phone = "";
        portable = "";
        default = [
          ""
          ""
          ""
        ];
      };
      on-click = pavucontrol;
      input = true;
    };
    tray = {
      format = "<span foreground='#957FB8'>{icon}</span>";
      icon-size = 14;
      spacing = 5;
    };
    bluetooth = {
      format = "{icon}";
      interval = 15;
      format-icons = {
        on = "<span foreground='#43242B'></span>";
        off = "<span foreground='#76946A'>󰂲</span>";
        disabled = "󰂲";
        connected = "";
      };
      tooltip-format = "{device_alias} {status}";
    };
    "custom/session" = {
      format = "";
      on-click = wlogout;
    };
  };
  programs.waybar.style = ''
    @define-color bg-hover #f28668;
    @define-color lbg #131721;
    @define-color bg #0b0e14;
    @define-color blue #73b8ff;
    @define-color sky #95e6cb;
    @define-color red #f07178;
    @define-color pink #f28779;
    @define-color lavender #d2a6ff;
    @define-color rosewater #f07178;
    @define-color flamingo #f07178;
    @define-color fg #bfbdb6;
    @define-color green #7fd962;
    @define-color active-green #aad94c;
    @define-color dark-fg #787bb0;
    @define-color peach #f2966b;
    @define-color border @lavender;
    @define-color gray2 #cccac2;
    @define-color black4 #0d1017;
    @define-color black3 #131721;
    @define-color maroon #d95757;
    @define-color yellow #FF8F40;

    * {
      min-height: 0;
      margin: 0;
      padding: 0;
      border-radius: 7px;
      font-family: "JetBrains Mono Nerd Font";
      font-size: 10pt;
      font-weight: 700;
      padding-bottom: 0px;
    }

    tooltip {
      background: @bg;
      border-radius: 7px;
      border: 2px solid @border;
    }

    #window {
      padding-left: 10px;
      padding-right: 7px;
      border-radius: 7px;
      border-bottom: 2px solid @bg;
      border-right: 2px solid @bg;
      background-color: @yellow;
      color: @bg;
    }

    window#waybar.empty #window {
      background-color: transparent;
      border-bottom: none;
      border-right: none;
    }

    window#waybar {
      background-color: transparent;
      color: @lavender;
    }

    /* Workspaces */
    @keyframes button_activate {
      from {
        opacity: .3
      }

      to {
        opacity: 1.;
      }
    }

    #workspaces {
      margin: 5px 5px 2px 5px;
      border-radius: 7px;
      padding: 1px 5px;
      background-color: @bg;
      color: @bg;

    }

    #workspaces button {
      margin: 5px 2px;
      border-radius: 5px;
      padding-left: 1px;
      padding-right: 1px;
      background-color: @bg;
      color: @fg;
    }

    #workspaces button.active {
      background-color: @yellow;
      color: @bg;
      /*color: @bg;*/

    }

    #workspaces button.urgent {
      color: #F38BA8;
    }

    #workspaces button:hover {
      border: solid transparent;
    }

    #tray,
    #custom-session {
      margin: 5px 5px 2px 5px;
      border-radius: 7px;
      padding-left: 10px;
      padding-right: 10px;
      background-color: @bg;
      color: @fg;
    }

    #network {
      margin: 5px 5px 2px 5px;
      padding-left: 10px;
      padding-right: 12px;
      border-radius: 7px;
      background-color: @bg;
      color: @lavender;
    }

    #network.linked {
      color: @peach;
    }

    #network.disconnected,
    #network.disabled {
      color: @red;
    }

    #bluetooth,
    #pulseaudio {
      margin-top: 5px;
      margin-bottom: 2px;
      color: @fg;
      background-color: @bg;
      border-top-right-radius: 0px;
      border-bottom-right-radius: 0px;
      border-top-left-radius: 7px;
      border-bottom-left-radius: 7px;

    }

    #bluetooth {
      margin-left: 0px;
      margin-right: 5px;
      padding-left: 7.5px;
      padding-right: 10px;
      border-top-left-radius: 0px;
      border-bottom-left-radius: 0px;
      border-top-right-radius: 7px;
      border-bottom-right-radius: 7px;
    }

    #pulseaudio {
      margin-right: 0px;
      margin-left: 5px;
      padding-left: 10px;
      padding-right: 7.5px;
      border-top-right-radius: 0px;
      border-bottom-right-radius: 0px;
      border-top-left-radius: 7px;
      border-bottom-left-radius: 7px;
    }

    #clock {
      margin: 5px 5px 2px 5px;
      padding-left: 10px;
      padding-right: 10px;
      border-radius: 7px;
      color: @fg;
      background-color: @bg;
    }

    #mode {
      margin: 5px 5px 2px 5px;
      padding-left: 10px;
      padding-right: 10px;
      border-radius: 7px;
      background-color: @bg;
      color: @peach;
    }
  '';
}
