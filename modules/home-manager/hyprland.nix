{ ... }:
{
  lib,
  config,
  pkgs,
  isLinux,
  ...
}:
let
  cfg = config.hyprland;
in
{
  options = {
    hyprland = {
      enable = lib.mkEnableOption "Hyprland" // {
        default = isLinux;
      };

      # Extra `hl.workspace_rule` fields merged into the generated rule for each
      # named workspace, e.g. `{ monitor = "DP-1"; }`. Field names use the Lua
      # API spelling (underscores), not the legacy hyprlang hyphens.
      workspace.extraRules =
        let
          workspaceExtraRulesOption = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
          };
        in
        {
          browser = workspaceExtraRulesOption;
          file-manager = workspaceExtraRulesOption;
          terminal = workspaceExtraRulesOption;
          discord = workspaceExtraRulesOption;
          steam = workspaceExtraRulesOption;
          obsidian = workspaceExtraRulesOption;
          messaging = workspaceExtraRulesOption;
          _1password = workspaceExtraRulesOption;
          twitter = workspaceExtraRulesOption;
          bambu-studio = workspaceExtraRulesOption;
        };
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;

      # Hyprland 0.55+ uses a Lua config. Home Manager maps each `settings`
      # attribute to an `hl.<name>(...)` call, so everything below is written in
      # the new Lua API shape: config sections nest under `config` (one
      # `hl.config({...})` call), keybinds use the `hl.dsp.*` dispatcher API,
      # monitors/gestures are tables, and startup programs run from the
      # `hyprland.start` hook.
      configType = "lua";

      settings =
        let
          inherit (lib.generators) mkLuaInline;

          menuBar = lib.getExe pkgs.waybar;
          awww = lib.getExe pkgs.awww;

          # Programs launched on their named workspaces.
          browser = lib.getExe config.browser;
          fileManager = lib.getExe config.fileManager;
          terminal = lib.getExe config.terminal;
          discord = lib.getExe pkgs.discord;
          steam = lib.getExe pkgs.steam;
          obsidian = lib.getExe pkgs.obsidian;
          telegram = lib.getExe pkgs.telegram-desktop;
          # Create both messaging clients together so Hyprland tiles them
          # side-by-side in the messaging workspace.
          messaging = "sh -c '${browser} --app=\"https://web.whatsapp.com\" & exec ${telegram}'";
          _1password = lib.getExe pkgs._1password-gui;
          twitter = ''${browser} --app="https://x.com/"'';
          bambu-studio = lib.getExe pkgs.bambu-studio;

          rofi = lib.getExe config.programs.rofi.package;
          launcher = "${rofi} -show drun";
          emoji = ''${rofi} -modi "emoji:rofimoji" -show emoji'';
          screenshot = lib.getExe pkgs.grimblast;
          brightness = lib.getExe pkgs.brightnessctl;
          media = lib.getExe pkgs.playerctl;

          # Keybind helpers: arg 1 is a key string ("SUPER + B"), arg 2 a
          # dispatcher (raw Lua `hl.dsp.*`), optional arg 3 a table of flags.
          mkBind = keys: dispatch: { _args = [ keys (mkLuaInline dispatch) ]; };
          mkBindOpts = keys: dispatch: opts: {
            _args = [ keys (mkLuaInline dispatch) opts ];
          };
          execDsp = cmd: "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
          wsFocus = name: ''hl.dsp.focus({ workspace = "name:${name}" })'';
          wsMove = name: ''hl.dsp.window.move({ workspace = "name:${name}" })'';
          focusDir = dir: ''hl.dsp.focus({ direction = "${dir}" })'';
          moveDir = dir: ''hl.dsp.window.move({ direction = "${dir}" })'';

          startupCommands = [
            # Wallpaper
            "${awww}-daemon"
            "${awww} img ~/dotfiles/assets/wallpaper.png -t none"

            menuBar
          ]
          # ++ lib.optional config.dropbox.enable "${lib.getExe pkgs.maestral} start"
          ;
        in
        {
          monitor = builtins.map (
            monitor:
            if monitor.enable then
              {
                output = monitor.name;
                mode = "${toString monitor.width}x${toString monitor.height}@${toString monitor.refreshRate}";
                position = "${toString monitor.x}x${toString monitor.y}";
                scale = monitor.scale;
              }
            else
              {
                output = monitor.name;
                disabled = true;
              }
          ) config.monitors;

          # Look and feel. These merge with Stylix's `hl.config` (colors,
          # shadow, background) into a single call — keep leaves distinct from
          # Stylix's (notably it owns `misc.disable_hyprland_logo`).
          config = {
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
            animations.enabled = false;
            input = {
              kb_layout = "us";
              kb_variant = "altgr-intl";
              kb_options = "ctrl:nocaps,lv3:ralt_switch";
              touchpad = {
                natural_scroll = true;
                scroll_factor = 0.5;
              };
            };
            misc.disable_splash_rendering = true;
            dwindle = {
              preserve_split = true;
              force_split = 2;
            };
            ecosystem.no_update_news = true;
            xwayland.force_zero_scaling = true;
          };

          env = {
            _args = [
              "XCURSOR_SIZE"
              "24"
            ];
          };

          gesture = {
            fingers = 4;
            direction = "horizontal";
            action = "workspace";
          };

          # Autostart: run programs from the start hook (the Lua-native
          # replacement for `exec-once`).
          on = {
            _args = [
              "hyprland.start"
              (mkLuaInline (
                "function()\n"
                + lib.concatMapStringsSep "\n" (cmd: "  hl.exec_cmd(${builtins.toJSON cmd})") startupCommands
                + "\n\n  hl.on(\"window.open\", function(window)\n"
                + "    if window.class == \"BambuStudio\" then\n"
                + "      hl.dispatch(hl.dsp.focus({ workspace = \"name:bambu-studio\" }))\n"
                + "    end\n"
                + "  end)"
                + "\nend"
              ))
            ];
          };

          workspace_rule =
            let
              rule =
                name: package:
                {
                  workspace = "name:${name}";
                  on_created_empty = package;
                }
                // cfg.workspace.extraRules.${name};
            in
            [
              (rule "browser" browser)
              (rule "file-manager" fileManager)
              (rule "terminal" terminal)
              (rule "discord" discord)
              (rule "steam" steam)
              (rule "obsidian" obsidian)
              (rule "messaging" messaging)
              (rule "_1password" _1password)
              (rule "twitter" twitter)
              (rule "bambu-studio" bambu-studio)
            ];

          # MakerWorld launches Bambu Studio directly through its URI handler,
          # bypassing `on_created_empty`. Route that window to the same workspace.
          window_rule = [
            {
              match.class = "^BambuStudio$";
              workspace = "name:bambu-studio";
            }
          ];

          bind =
            let
              moveWorkspaceToMonitor = lib.imap1 (
                index: monitor:
                mkBind "SUPER + ALT + ${toString index}" "hl.dsp.workspace.move({ monitor = ${builtins.toJSON monitor.name} })"
              ) config.monitors;

              workspaceNumbers = builtins.genList (
                i:
                let
                  n = i + 1;
                  key = if n == 10 then "0" else toString n;
                in
                mkBind "SUPER + ${key}" "hl.dsp.focus({ workspace = ${toString n} })"
              ) 10;

              moveToWorkspaceNumbers = builtins.genList (
                i:
                let
                  n = i + 1;
                  key = if n == 10 then "0" else toString n;
                in
                mkBind "SUPER + SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${toString n} })"
              ) 10;
            in
            moveWorkspaceToMonitor
            ++ [
              # Focus named workspaces
              (mkBind "SUPER + B" (wsFocus "browser"))
              (mkBind "SUPER + D" (wsFocus "discord"))
              (mkBind "SUPER + G" (wsFocus "steam"))
              (mkBind "SUPER + F" (wsFocus "file-manager"))
              (mkBind "SUPER + T" (wsFocus "terminal"))
              (mkBind "SUPER + O" (wsFocus "obsidian"))
              (mkBind "SUPER + M" (wsFocus "messaging"))
              (mkBind "SUPER + P" (wsFocus "_1password"))
              (mkBind "SUPER + X" (wsFocus "twitter"))
              (mkBind "SUPER + C" (wsFocus "bambu-studio"))

              # Move active window to named workspaces
              (mkBind "SUPER + SHIFT + B" (wsMove "browser"))
              (mkBind "SUPER + SHIFT + D" (wsMove "discord"))
              (mkBind "SUPER + SHIFT + G" (wsMove "steam"))
              (mkBind "SUPER + SHIFT + F" (wsMove "file-manager"))
              (mkBind "SUPER + SHIFT + T" (wsMove "terminal"))
              (mkBind "SUPER + SHIFT + O" (wsMove "obsidian"))
              (mkBind "SUPER + SHIFT + M" (wsMove "messaging"))
              (mkBind "SUPER + SHIFT + P" (wsMove "_1password"))
              (mkBind "SUPER + SHIFT + X" (wsMove "twitter"))
              (mkBind "SUPER + SHIFT + C" (wsMove "bambu-studio"))

              (mkBind "SUPER + Escape" "hl.dsp.window.close()")
              (mkBind "SUPER + V" ''hl.dsp.window.float({ action = "toggle" })'')
              (mkBind "SUPER + F11" ''hl.dsp.window.fullscreen({ mode = "maximized" })'')
              (mkBind "SUPER + Return" (execDsp terminal))
              (mkBind "SUPER + Space" (execDsp launcher))
              (mkBind "SUPER + period" (execDsp emoji))
              (mkBind "SUPER + SHIFT + W" (execDsp "pkill ${builtins.baseNameOf menuBar} || ${menuBar}"))

              # Move focus
              (mkBind "SUPER + left" (focusDir "left"))
              (mkBind "SUPER + right" (focusDir "right"))
              (mkBind "SUPER + up" (focusDir "up"))
              (mkBind "SUPER + down" (focusDir "down"))
              (mkBind "SUPER + H" (focusDir "left"))
              (mkBind "SUPER + L" (focusDir "right"))
              (mkBind "SUPER + K" (focusDir "up"))
              (mkBind "SUPER + J" (focusDir "down"))

              # Move window
              (mkBind "SUPER + SHIFT + left" (moveDir "left"))
              (mkBind "SUPER + SHIFT + right" (moveDir "right"))
              (mkBind "SUPER + SHIFT + up" (moveDir "up"))
              (mkBind "SUPER + SHIFT + down" (moveDir "down"))
              (mkBind "SUPER + SHIFT + H" (moveDir "left"))
              (mkBind "SUPER + SHIFT + L" (moveDir "right"))
              (mkBind "SUPER + SHIFT + K" (moveDir "up"))
              (mkBind "SUPER + SHIFT + J" (moveDir "down"))
            ]
            ++ workspaceNumbers
            ++ [
              (mkBind "SUPER + S" ''hl.dsp.workspace.toggle_special("scratchpad")'')
            ]
            ++ moveToWorkspaceNumbers
            ++ [
              (mkBind "SUPER + SHIFT + S" ''hl.dsp.window.move({ workspace = "special:scratchpad" })'')

              # Scroll through existing workspaces
              (mkBind "SUPER + mouse_down" ''hl.dsp.focus({ workspace = "e+1" })'')
              (mkBind "SUPER + mouse_up" ''hl.dsp.focus({ workspace = "e-1" })'')

              # Screenshot
              # Force a rectangular Slurp selection. Grim's window-target capture
              # (`-T`), which Grimblast chooses on a window click, can hang on
              # Hyprland 0.56 and leaves the screenshot lock behind.
              (mkBind "Print" (execDsp "SLURP_RECTS= ${screenshot} copy area"))

              # Move windows with SUPER + LMB and dragging
              (mkBindOpts "SUPER + mouse:272" "hl.dsp.window.drag()" { mouse = true; })

              # Volume (repeat, works while locked)
              (mkBindOpts "XF86AudioRaiseVolume" (execDsp "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0") {
                locked = true;
                repeating = true;
              })
              (mkBindOpts "XF86AudioLowerVolume" (execDsp "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0") {
                locked = true;
                repeating = true;
              })
              (mkBindOpts "SUPER + XF86AudioRaiseVolume"
                (execDsp "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+ --limit 1.0")
                {
                  locked = true;
                  repeating = true;
                }
              )
              (mkBindOpts "SUPER + XF86AudioLowerVolume"
                (execDsp "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- --limit 1.0")
                {
                  locked = true;
                  repeating = true;
                }
              )

              # Brightness (repeat, works while locked)
              (mkBindOpts "XF86MonBrightnessUp" (execDsp "${brightness} set 5%+") {
                locked = true;
                repeating = true;
              })
              (mkBindOpts "XF86MonBrightnessDown" (execDsp "${brightness} set 5%-") {
                locked = true;
                repeating = true;
              })

              # Mute + media (works while locked)
              (mkBindOpts "XF86AudioMute" (execDsp "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") {
                locked = true;
              })
              (mkBindOpts "XF86AudioPlay" (execDsp "${media} play-pause") { locked = true; })
              (mkBindOpts "XF86AudioPrev" (execDsp "${media} previous") { locked = true; })
              (mkBindOpts "XF86AudioNext" (execDsp "${media} next") { locked = true; })
              (mkBindOpts "XF86AudioStop" (execDsp "${media} stop") { locked = true; })
            ];
        };
    };
  };
}
