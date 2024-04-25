{ config, pkgs, ... }:


let
  main-modifier = "SUPER";
  terminal = "${pkgs.alacritty}/bin/alacritty";
  launcher = "${pkgs.wofi}/bin/wofi --show drun";
  fileManager = "${pkgs.gnome.nautilus}/bin/nautilus";
  browser = "${pkgs.brave}/bin/brave";
  menu-bar = "${pkgs.waybar}/bin/waybar";
  wallpaper-daemon = "${pkgs.wpaperd}/bin/wpaperd";
  # Screenshot
  screenshot = "${pkgs.grimblast}/bin/grimblast";
  brightness = "${pkgs.brightnessctl}/bin/brightnessctl";
  media = "${pkgs.playerctl}/bin/playerctl";
in
{
  wayland.windowManager.hyprland = {
    enable = config.hyprland.enable;

    settings = {
      monitor = map
        (m:
          let
            resolution = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
            position = "${toString m.x}x${toString m.y}";
          in
          "${m.name}, ${if m.enable then "${resolution}, ${position}, ${toString m.scale}" else "disable"}"
        )
        (config.monitors);
      general = {
        border_size = 2;
        gaps_in = 4;
        gaps_out = 8;
        "col.inactive_border" = "rgba(595959aa)";
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        layout = "dwindle";
        resize_on_border = true;
      };
      decoration = {
        rounding = 10;
        blur = {
          enabled = true;
          xray = true;
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
      input = {
        touchpad.natural_scroll = config.touchpad.enable;
      };
      gestures = {
        workspace_swipe = config.touchpad.enable;
        workspace_swipe_fingers = 4;
      };
      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };
      dwindle = {
        pseudotile = true;
        preserve_split = true;
        force_split = 2;
      };
      master = {
        new_is_master = false;
      };
      xwayland = {
        force_zero_scaling = config.touchpad.enable;
      };
      env = [
        "XCURSOR_SIZE, 24"
      ];
      exec-once = [
        menu-bar
        wallpaper-daemon
      ];
      bind = [
        "${main-modifier}, C, killactive,"
        "${main-modifier}, V, togglefloating,"
        "${main-modifier}, P, fullscreen, 1"
        "${main-modifier}, T, exec, ${terminal}"
        "${main-modifier}, F, exec, ${fileManager}"
        "${main-modifier}, R, exec, ${launcher}"
        "${main-modifier}, B, exec, ${browser}"
        "${main-modifier}, W, exec, pkill waybar || ${menu-bar}"

        # Move focus
        "${main-modifier}, left, movefocus, l"
        "${main-modifier}, right, movefocus, r"
        "${main-modifier}, up, movefocus, u"
        "${main-modifier}, down, movefocus, d"
        "${main-modifier}, H, movefocus, l"
        "${main-modifier}, L, movefocus, r"
        "${main-modifier}, K, movefocus, u"
        "${main-modifier}, J, movefocus, d"
        # Move window
        "${main-modifier}_SHIFT, left, movewindow, l"
        "${main-modifier}_SHIFT, right, movewindow, r"
        "${main-modifier}_SHIFT, up, movewindow, u"
        "${main-modifier}_SHIFT, down, movewindow, d"
        "${main-modifier}_SHIFT, H, movewindow, l"
        "${main-modifier}_SHIFT, L, movewindow, r"
        "${main-modifier}_SHIFT, K, movewindow, u"
        "${main-modifier}_SHIFT, J, movewindow, d"

        # Switch workspaces with mainMod + [0-9]
        "${main-modifier}, 1, workspace, 1"
        "${main-modifier}, 2, workspace, 2"
        "${main-modifier}, 3, workspace, 3"
        "${main-modifier}, 4, workspace, 4"
        "${main-modifier}, 5, workspace, 5"
        "${main-modifier}, 6, workspace, 6"
        "${main-modifier}, 7, workspace, 7"
        "${main-modifier}, 8, workspace, 8"
        "${main-modifier}, 9, workspace, 9"
        "${main-modifier}, 0, workspace, 10"
        "${main-modifier}, S, togglespecialworkspace, special:scratchpad"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "${main-modifier}_SHIFT, 1, movetoworkspace, 1"
        "${main-modifier}_SHIFT, 2, movetoworkspace, 2"
        "${main-modifier}_SHIFT, 3, movetoworkspace, 3"
        "${main-modifier}_SHIFT, 4, movetoworkspace, 4"
        "${main-modifier}_SHIFT, 5, movetoworkspace, 5"
        "${main-modifier}_SHIFT, 6, movetoworkspace, 6"
        "${main-modifier}_SHIFT, 7, movetoworkspace, 7"
        "${main-modifier}_SHIFT, 8, movetoworkspace, 8"
        "${main-modifier}_SHIFT, 9, movetoworkspace, 9"
        "${main-modifier}_SHIFT, 0, movetoworkspace, 10"
        "${main-modifier}_SHIFT, S, movetoworkspace, special:scratchpad"

        # Scroll through existing workspaces with mainMod + scroll
        "${main-modifier}, mouse_down, workspace, e+1"
        "${main-modifier}, mouse_up, workspace, e-1"

        # Screenshot
        ", Print, exec, ${screenshot} --cursor copy area"
      ];
      # Mouse
      bindm = [
        # Move windows with mainMod + LMB and dragging
        "${main-modifier}, mouse:272, movewindow"
      ];
      # Repeat - Locked
      bindel = [
        # Volume
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0"
        "${main-modifier}, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+ --limit 1.0"
        "${main-modifier}, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- --limit 1.0"

        # Brightness
        ", XF86MonBrightnessUp, exec, ${brightness} set 5%+"
        ", XF86MonBrightnessDown, exec, ${brightness} set 5%-"
      ];
      # Locked
      bindl = [
        # Mute Volume        
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"

        # Media
        ", XF86AudioPlay, exec, ${media} play-pause"
        ", XF86AudioPrev, exec, ${media} previous"
        ", XF86AudioNext, exec, ${media} next"
        ", XF86AudioNext, exec, ${media} next"
        ", XF86AudioStop, exec, ${media} stop"
      ];
    };
  };
}
