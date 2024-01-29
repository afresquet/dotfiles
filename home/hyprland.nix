{ pkgs, ... }:
let 
  mainMod = "SUPER";
  terminal = "${pkgs.alacritty}/bin/alacritty";
  menu = "${pkgs.wofi}/bin/wofi --show drun";
  fileManager = "${pkgs.dolphin}/bin/dolphin";
  browser = "${pkgs.brave}/bin/brave";
  waybar = "${pkgs.waybar}/bin/waybar";
in {
  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    monitor = [
      "DP-1, 1920x1080@59.96, 0x0, 1"
      "HDMI-1, 1920x1080@59.96, 1920x0, 1"
    ];
    input = {
      kb_layout = "us";
      # kb_options = "caps:super";
      follow_mouse = 1;
      sensitivity = 0; # -1.0 - 1.0, 0 means no modification.
    };
    general = {
      # See https://wiki.hyprland.org/Configuring/Variables/ for more
      gaps_in = 6;
      gaps_out = 8;
      border_size = 2;
      "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
      "col.inactive_border" = "rgba(595959aa)";
      layout = "dwindle";
      # resize_on_border = true;
    };
    decoration = {
      # See https://wiki.hyprland.org/Configuring/Variables/ for more
      rounding = 10;
      blur = {
          enabled = true;
          size = 5;
          passes = 3;
          vibrancy = 0.1696;
      };
      drop_shadow = true;
    };
    animations = {
      enabled = true;
      # Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
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
    dwindle = {
      # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
      pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
      preserve_split = true; # you probably want this
    };
    master = {
      # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
      new_is_master = true;
    };
    misc = {
      # See https://wiki.hyprland.org/Configuring/Variables/ for more
      force_default_wallpaper = 0; # Set to 0 to disable the anime mascot wallpapers
    };
    env = [
      "XCURSOR_SIZE, 24"
    ];
    exec-once = [
      waybar
    ];
    bind = [
      # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
      "${mainMod}, P, exec, ${terminal}"
      "${mainMod}, C, killactive,"
      # "${mainMod}, M, exit,"
      "${mainMod}, F, exec, ${fileManager}"
      "${mainMod}, V, togglefloating,"
      "${mainMod}, R, exec, ${menu}"
      "${mainMod}, B, exec, ${browser}"
      # "${mainMod}, P, pseudo, # dwindle"
      # "${mainMod}, J, togglesplit, # dwindle"

      # Move focus with mainMod + arrow keys
      "${mainMod}, H, movefocus, l"
      "${mainMod}, L, movefocus, r"
      "${mainMod}, J, movefocus, u"
      "${mainMod}, K, movefocus, d"

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

      # Example special workspace (scratchpad)
      "${mainMod}, S, togglespecialworkspace, magic"
      "${mainMod}_SHIFT, S, movetoworkspace, special:magic"

      # Scroll through existing workspaces with mainMod + scroll
      "${mainMod}, mouse_down, workspace, e+1"
      "${mainMod}, mouse_up, workspace, e-1"

      # Move/resize windows with mainMod + LMB/RMB and dragging
      # "${mainMod}, mouse:272, movewindow"
      # "${mainMod}, mouse:273, resizewindow"
    ];
  };
}
