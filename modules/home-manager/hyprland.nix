{ ... }:
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hyprland;
in
{
  options = {
    hyprland = {
      enable = lib.mkEnableOption "Hyprland" // {
        default = true;
      };

      workspace.extraRules =
        let
          workspaceExtraRulesOption = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        in
        {
          browser = workspaceExtraRulesOption;
          file-manager = workspaceExtraRulesOption;
          terminal = workspaceExtraRulesOption;
          discord = workspaceExtraRulesOption;
          obsidian = workspaceExtraRulesOption;
          whatsapp = workspaceExtraRulesOption;
          music = workspaceExtraRulesOption;
          _1password = workspaceExtraRulesOption;
          twitter = workspaceExtraRulesOption;
        };
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;

      settings =
        let
          modKey = "SUPER";
          menuBar = lib.getExe pkgs.waybar;

          mapMonitors =
            monitor:
            let
              resolution = "${toString monitor.width}x${toString monitor.height}@${toString monitor.refreshRate}";
              position = "${toString monitor.x}x${toString monitor.y}";
            in
            "${monitor.name}, ${
              if monitor.enable then "${resolution}, ${position}, ${toString monitor.scale}" else "disable"
            }";
        in
        {
          monitor = builtins.map (mapMonitors) (config.monitors);
          general = {
            border_size = 2;
            gaps_in = 4;
            gaps_out = 8;
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
            enabled = false;
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
            kb_options = "ctrl:nocaps";
            touchpad = {
              natural_scroll = true;
              scroll_factor = 0.5;
            };
          };
          gestures = {
            workspace_swipe = true;
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
          xwayland = {
            force_zero_scaling = true;
          };
          env = [ "XCURSOR_SIZE, 24" ];
          exec-once =
            let
              swww = lib.getExe pkgs.swww;
            in
            [
              # Wallpaper
              "${swww}-daemon"
              ''${swww} img ~/dotfiles/assets/wallpaper.png -t none''

              menuBar

              # Dropbox
              "${lib.getExe pkgs.maestral} start"
            ];
          workspace =
            let
              browser = lib.getExe config.browser;
              fileManager = lib.getExe config.fileManager;
              terminal = lib.getExe config.terminal;
              discord = lib.getExe pkgs.discord;
              obsidian = lib.getExe pkgs.obsidian;
              whatsapp = ''${browser} --app="https://web.whatsapp.com"'';
              music = ''${browser} --app="https://music.youtube.com/"'';
              _1password = lib.getExe pkgs._1password-gui;
              twitter = ''${browser} --app="https://x.com/"'';

              merge = rules: builtins.concatStringsSep ", " (builtins.concatLists rules);
              rule =
                name: package:
                let
                  defaultRules = [
                    "name:${name}"
                    "on-created-empty:${package}"
                  ];
                in
                merge [
                  defaultRules
                  cfg.workspace.extraRules.${name}
                ];
            in
            [
              (rule "browser" browser)
              (rule "file-manager" fileManager)
              (rule "terminal" terminal)
              (rule "discord" discord)
              (rule "obsidian" obsidian)
              (rule "whatsapp" whatsapp)
              (rule "music" music)
              (rule "_1password" _1password)
              (rule "twitter" twitter)
            ];
          windowrulev2 = [ "noborder, onworkspace:1" ];
          bind =
            let
              rofi = lib.getExe config.programs.rofi.package;
              launcher = "${rofi} -show drun";
              emoji = ''${rofi} -modi "emoji:rofimoji" -show emoji'';
              screenshot = lib.getExe pkgs.grimblast;
              moveWorkspaceToMonitor = lib.imap (
                index: monitor: "${modKey}_ALT, ${toString index}, movecurrentworkspacetomonitor, ${monitor.name}"
              ) config.monitors;
            in
            moveWorkspaceToMonitor
            ++ [
              "${modKey}, B, workspace, name:browser"
              "${modKey}, D, workspace, name:discord"
              "${modKey}, F, workspace, name:file-manager"
              "${modKey}, T, workspace, name:terminal"
              "${modKey}, O, workspace, name:obsidian"
              "${modKey}, W, workspace, name:whatsapp"
              "${modKey}, M, workspace, name:music"
              "${modKey}, P, workspace, name:_1password"
              "${modKey}, X, workspace, name:twitter"

              "${modKey}_SHIFT, B, movetoworkspace, name:browser"
              "${modKey}_SHIFT, D, movetoworkspace, name:discord"
              "${modKey}_SHIFT, F, movetoworkspace, name:file-manager"
              "${modKey}_SHIFT, T, movetoworkspace, name:terminal"
              "${modKey}_SHIFT, O, movetoworkspace, name:obsidian"
              "${modKey}_SHIFT, M, movetoworkspace, name:music"
              "${modKey}_SHIFT, P, movetoworkspace, name:_1password"
              "${modKey}_SHIFT, X, movetoworkspace, name:twitter"

              "${modKey}, Escape, killactive,"
              "${modKey}, V, togglefloating,"
              "${modKey}, F11, fullscreen, 1"
              "${modKey}, Return, exec, ${lib.getExe config.terminal}"
              "${modKey}, Space, exec, ${launcher}"
              "${modKey}, period, exec, ${emoji}"
              "${modKey}_SHIFT, W, exec, pkill ${builtins.baseNameOf menuBar} || ${menuBar}"

              # Move focus
              "${modKey}, left, movefocus, l"
              "${modKey}, right, movefocus, r"
              "${modKey}, up, movefocus, u"
              "${modKey}, down, movefocus, d"
              "${modKey}, H, movefocus, l"
              "${modKey}, L, movefocus, r"
              "${modKey}, K, movefocus, u"
              "${modKey}, J, movefocus, d"
              # Move window
              "${modKey}_SHIFT, left, movewindow, l"
              "${modKey}_SHIFT, right, movewindow, r"
              "${modKey}_SHIFT, up, movewindow, u"
              "${modKey}_SHIFT, down, movewindow, d"
              "${modKey}_SHIFT, H, movewindow, l"
              "${modKey}_SHIFT, L, movewindow, r"
              "${modKey}_SHIFT, K, movewindow, u"
              "${modKey}_SHIFT, J, movewindow, d"

              # Switch workspaces with mainMod + [0-9]
              "${modKey}, 1, workspace, 1"
              "${modKey}, 2, workspace, 2"
              "${modKey}, 3, workspace, 3"
              "${modKey}, 4, workspace, 4"
              "${modKey}, 5, workspace, 5"
              "${modKey}, 6, workspace, 6"
              "${modKey}, 7, workspace, 7"
              "${modKey}, 8, workspace, 8"
              "${modKey}, 9, workspace, 9"
              "${modKey}, 0, workspace, 10"
              "${modKey}, S, togglespecialworkspace, special:scratchpad"

              # Move active window to a workspace with mainMod + SHIFT + [0-9]
              "${modKey}_SHIFT, 1, movetoworkspace, 1"
              "${modKey}_SHIFT, 2, movetoworkspace, 2"
              "${modKey}_SHIFT, 3, movetoworkspace, 3"
              "${modKey}_SHIFT, 4, movetoworkspace, 4"
              "${modKey}_SHIFT, 5, movetoworkspace, 5"
              "${modKey}_SHIFT, 6, movetoworkspace, 6"
              "${modKey}_SHIFT, 7, movetoworkspace, 7"
              "${modKey}_SHIFT, 8, movetoworkspace, 8"
              "${modKey}_SHIFT, 9, movetoworkspace, 9"
              "${modKey}_SHIFT, 0, movetoworkspace, 10"
              "${modKey}_SHIFT, S, movetoworkspace, special:scratchpad"

              # Scroll through existing workspaces with mainMod + scroll
              "${modKey}, mouse_down, workspace, e+1"
              "${modKey}, mouse_up, workspace, e-1"

              # Screenshot
              ", Print, exec, ${screenshot} --cursor copy area"
            ];
          # Mouse
          bindm = [
            # Move windows with mainMod + LMB and dragging
            "${modKey}, mouse:272, movewindow"
          ];
          # Repeat - Locked
          bindel =
            let
              brightness = lib.getExe pkgs.brightnessctl;
            in
            [
              # Volume
              ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0"
              ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0"
              "${modKey}, XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+ --limit 1.0"
              "${modKey}, XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- --limit 1.0"

              # Brightness
              ", XF86MonBrightnessUp, exec, ${brightness} set 5%+"
              ", XF86MonBrightnessDown, exec, ${brightness} set 5%-"
            ];
          # Locked
          bindl =
            let
              media = lib.getExe pkgs.playerctl;
            in
            [
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
  };
}
