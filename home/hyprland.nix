{ pkgs, ... }:
let 
  mainMod = "SUPER";
  terminal = "${pkgs.alacritty}/bin/alacritty";
  menu = "${pkgs.wofi}/bin/wofi --show drun";
  fileManager = "${pkgs.dolphin}/bin/dolphin";
  browser = "${pkgs.brave}/bin/brave";
  wpaperd = "${pkgs.wpaperd}/bin/wpaperd";
in {
  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    monitor = [
      "DP-1, 1920x1080@59.96, 0x0, 1"
      "HDMI-1, 1920x1080@59.96, 1920x0, 1"
    ];
    general = {
      border_size = 2;
      gaps_in = 8;
      gaps_out = 16;
      "col.inactive_border" = "rgba(595959aa)";
      "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
      layout = "master";
      resize_on_border = true;
    };
    decoration = {
      rounding = 10;
      blur = {
          enabled = true;
          size = 5;
          passes = 3;
      };
    };
    animations = {
      enabled = true;
      bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
      animation = [
        "windows, 1, 7, myBezier"
        "windowsOut, 1, 7, default, popin 80%"
        "border, 1, 10, default"
        "borderangle, 1, 8, default"
        "fade, 1, 7, default"
        "workspaces, 1, 6, default"
      ];
    };
    misc = {
      disable_hyprland_logo = true;
      disable_splash_rendering = true;
    };
    master = {
      new_is_master = false;
    };
    env = [
      "XCURSOR_SIZE, 24"
    ];
    exec-once = [
      wpaperd
    ];
    bind = [
      "${mainMod}, P, exec, ${terminal}"
      "${mainMod}, C, killactive,"
      "${mainMod}, F, exec, ${fileManager}"
      "${mainMod}, V, togglefloating,"
      "${mainMod}, R, exec, ${menu}"
      "${mainMod}, B, exec, ${browser}"

      # Move focus
      "${mainMod}, left, movefocus, l"
      "${mainMod}, right, movefocus, r"
      "${mainMod}, up, movefocus, u"
      "${mainMod}, down, movefocus, d"
      "${mainMod}, H, movefocus, l"
      "${mainMod}, L, movefocus, r"
      "${mainMod}, K, movefocus, u"
      "${mainMod}, J, movefocus, d"
      # Move window
      "${mainMod}_SHIFT, left, movewindow, l"
      "${mainMod}_SHIFT, right, movewindow, r"
      "${mainMod}_SHIFT, up, movewindow, u"
      "${mainMod}_SHIFT, down, movewindow, d"
      "${mainMod}_SHIFT, H, movewindow, l"
      "${mainMod}_SHIFT, L, movewindow, r"
      "${mainMod}_SHIFT, K, movewindow, u"
      "${mainMod}_SHIFT, J, movewindow, d"

      # Switch workspaces with mainMod + [0-9]
      "${mainMod}, 1, workspace, 1"
      "${mainMod}, 2, workspace, 2"
      "${mainMod}, 3, workspace, 3"
      "${mainMod}, 4, workspace, 4"
      "${mainMod}, 5, workspace, 5"
      "${mainMod}, 6, workspace, 6"
      "${mainMod}, 7, workspace, 7"
      "${mainMod}, 8, workspace, 8"
      "${mainMod}, 9, workspace, 9"
      "${mainMod}, 0, workspace, 10"

      # Move active window to a workspace with mainMod + SHIFT + [0-9]
      "${mainMod}_SHIFT, 1, movetoworkspace, 1"
      "${mainMod}_SHIFT, 2, movetoworkspace, 2"
      "${mainMod}_SHIFT, 3, movetoworkspace, 3"
      "${mainMod}_SHIFT, 4, movetoworkspace, 4"
      "${mainMod}_SHIFT, 5, movetoworkspace, 5"
      "${mainMod}_SHIFT, 6, movetoworkspace, 6"
      "${mainMod}_SHIFT, 7, movetoworkspace, 7"
      "${mainMod}_SHIFT, 8, movetoworkspace, 8"
      "${mainMod}_SHIFT, 9, movetoworkspace, 9"
      "${mainMod}_SHIFT, 0, movetoworkspace, 10"

      # Scroll through existing workspaces with mainMod + scroll
      "${mainMod}, mouse_down, workspace, e+1"
      "${mainMod}, mouse_up, workspace, e-1"

      # Move/resize windows with mainMod + LMB/RMB and dragging
      "${mainMod}, mouse:272, movewindow"
      "${mainMod}, mouse:273, resizewindowpixel"
    ];
  };
}
