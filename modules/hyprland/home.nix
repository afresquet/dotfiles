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

      # Named workspaces. Each one gets a `hl.workspace_rule`, a Waybar icon
      # and (elsewhere in this module) its launch keybind.
      workspaces = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              icon = lib.mkOption {
                type = lib.types.str;
                description = "Icon Waybar shows for the workspace.";
              };
              extraRules = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = { };
                example = {
                  monitor = "DP-1";
                };
                description = ''
                  Extra `hl.workspace_rule` fields for this workspace. Field
                  names use the Lua API spelling (underscores), not the legacy
                  hyprlang hyphens.
                '';
              };
            };
          }
        );
        default = { };
      };
    };
  };

  config = lib.mkMerge [
    {
      hyprland.workspaces = {
        browser.icon = "";
        file-manager.icon = "";
        terminal.icon = "";
        discord.icon = "";
        steam.icon = "";
        obsidian.icon = "";
        messaging.icon = "󰍡";
        _1password.icon = "";
        twitter.icon = "";
        music.icon = "󰝚";
        bambu-studio.icon = "";
        herdr.icon = "󱙺";
      };
    }

    (lib.mkIf cfg.enable {
      stylix.cursor = {
        package = pkgs.bibata-cursors-black-corners;
        name = "Bibata-Modern-Classic-Black-Corners";
        size = 24;
      };

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
            webApp =
              name:
              let
                inherit (config.programs.firefoxpwa) package profiles;
                sites = lib.concatMapAttrs (_: profile: profile.sites) profiles;
                ulid = lib.findFirst (ulid: sites.${ulid}.name == name) (throw "no firefoxpwa site named ${name}") (
                  builtins.attrNames sites
                );
              in
              "${lib.getExe package} site launch ${ulid}";
            fileManager = lib.getExe config.fileManager;
            terminal = lib.getExe config.terminal;
            discord = lib.getExe pkgs.discord;
            steam = lib.getExe pkgs.steam;
            obsidian = lib.getExe pkgs.obsidian;
            telegram = lib.getExe pkgs.telegram-desktop;
            # Create both messaging clients together so Hyprland tiles them
            # side-by-side in the messaging workspace.
            messaging = "sh -c '${webApp "WhatsApp"} & exec ${telegram}'";
            _1password = lib.getExe pkgs._1password-gui;
            twitter = webApp "X";
            music = webApp "Apple Music";
            bambu-studio = lib.getExe pkgs.bambu-studio;
            herdr = lib.getExe config.herdr-desktop.package;

            rofi = lib.getExe config.programs.rofi.package;
            launcher = "${rofi} -show drun";
            emoji = ''${rofi} -modi "emoji:rofimoji" -show emoji'';
            screenshot = lib.getExe pkgs.grimblast;
            brightness = lib.getExe pkgs.brightnessctl;
            media = lib.getExe pkgs.playerctl;

            # Volume, mic and brightness keys go through swayosd for the popup.
            osd = lib.getExe' config.services.swayosd.package "swayosd-client";
            keyCmd =
              if config.swayosd.enable then
                {
                  volumeUp = "${osd} --output-volume +5";
                  volumeDown = "${osd} --output-volume -5";
                  mute = "${osd} --output-volume mute-toggle";
                  micUp = "${osd} --input-volume +5";
                  micDown = "${osd} --input-volume -5";
                  micMute = "${osd} --input-volume mute-toggle";
                  brightnessUp = "${osd} --brightness +5";
                  brightnessDown = "${osd} --brightness -5";
                }
              else
                {
                  volumeUp = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ --limit 1.0";
                  volumeDown = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- --limit 1.0";
                  mute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
                  micUp = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+ --limit 1.0";
                  micDown = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%- --limit 1.0";
                  micMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
                  brightnessUp = "${brightness} set 5%+";
                  brightnessDown = "${brightness} set 5%-";
                };

            # Shown by the SUPER + ? cheat sheet; binds without one are left out.
            bindDescriptions = {
              "SUPER + B" = "Browser";
              "SUPER + T" = "Terminal";
              "SUPER + D" = "Discord";
              "SUPER + M" = "Music";
              "SUPER + C" = "Herdr";
              "SUPER + O" = "Open… (then a letter)";
              "SUPER + SHIFT + B" = "Move window to browser";
              "SUPER + SHIFT + T" = "Move window to terminal";
              "SUPER + SHIFT + D" = "Move window to Discord";
              "SUPER + SHIFT + M" = "Move window to music";
              "SUPER + SHIFT + C" = "Move window to Herdr";
              "SUPER + Q" = "Close window";
              "SUPER + V" = "Toggle floating";
              "SUPER + F" = "Toggle fullscreen";
              "SUPER + SHIFT + F" = "Toggle maximized";
              "SUPER + E" = "Toggle split direction";
              "SUPER + Tab" = "Previous workspace";
              "SUPER + grave" = "Next window";
              "SUPER + SHIFT + grave" = "Previous window";
              "SUPER + bracketleft" = "Focus previous monitor";
              "SUPER + bracketright" = "Focus next monitor";
              "SUPER + Return" = "New terminal";
              "SUPER + Space" = "App launcher";
              "SUPER + period" = "Emoji picker";
              "SUPER + SHIFT + slash" = "This cheat sheet";
              "SUPER + SHIFT + W" = "Toggle Waybar";
              "SUPER + N" = "Notification center";
              "SUPER + SHIFT + V" = "Clipboard history";
              "SUPER + H" = "Focus left (or arrows)";
              "SUPER + L" = "Focus right";
              "SUPER + K" = "Focus up";
              "SUPER + J" = "Focus down";
              "SUPER + SHIFT + H" = "Move window left (or arrows)";
              "SUPER + SHIFT + L" = "Move window right";
              "SUPER + SHIFT + K" = "Move window up";
              "SUPER + SHIFT + J" = "Move window down";
              "SUPER + CTRL + H" = "Shrink width (or arrows)";
              "SUPER + CTRL + L" = "Grow width";
              "SUPER + CTRL + K" = "Shrink height";
              "SUPER + CTRL + J" = "Grow height";
              "SUPER + Escape" = "Lock screen";
              "SUPER + 1" = "Workspace 1–10 (1…0)";
              "SUPER + SHIFT + 1" = "Move window to workspace 1–10 (1…0)";
              "SUPER + ALT + 1" = "Move workspace to monitor 1, 2…";
              "SUPER + S" = "Toggle scratchpad";
              "SUPER + SHIFT + S" = "Move window to scratchpad";
              "Print" = "Screenshot area";
              "SHIFT + Print" = "Screenshot window";
              "SUPER + Print" = "Screenshot monitor";
              "SUPER + mouse:272" = "Drag to move window";
              "SUPER + mouse:273" = "Drag to resize window";
            };

            # Keybind helpers: arg 1 is a key string ("SUPER + B"), arg 2 a
            # dispatcher (raw Lua `hl.dsp.*`), optional arg 3 a table of flags.
            mkBindOpts = keys: dispatch: opts: {
              _args = [
                keys
                (mkLuaInline dispatch)
                (
                  opts
                  // lib.optionalAttrs (bindDescriptions ? ${keys}) {
                    description = bindDescriptions.${keys};
                  }
                )
              ];
            };
            mkBind = keys: dispatch: mkBindOpts keys dispatch { };

            # Lists the binds that have a description, from the live config.
            cheatSheet = pkgs.writeShellScript "hypr-keybinds" ''
              ${lib.getExe' config.wayland.windowManager.hyprland.finalPackage "hyprctl"} binds -j \
                | ${lib.getExe pkgs.jq} -r '
                  def mods: [
                    (if . / 64 | floor % 2 == 1 then "SUPER" else empty end),
                    (if . / 4 | floor % 2 == 1 then "CTRL" else empty end),
                    (if . / 8 | floor % 2 == 1 then "ALT" else empty end),
                    (if . % 2 == 1 then "SHIFT" else empty end)
                  ];
                  .[] | select(.has_description)
                  | ((.modmask | mods) + [.key] | join(" + ")) as $keys
                  | (if .submap == "" then $keys else "SUPER + O, \($keys)" end) as $keys
                  | "\($keys)\t\(.description)"' \
                | ${lib.getExe' pkgs.util-linux "column"} -t -s $'\t' \
                | ${rofi} -dmenu -i -no-custom -no-show-icons -p 󰌌 \
                    -theme-str 'window { width: 820px; } listview { lines: 14; }'
            '';
            execDsp = cmd: "hl.dsp.exec_cmd(${builtins.toJSON cmd})";
            # Hyprland 0.56 creates workspaces from `focus` as non-empty, so
            # `on_created_empty` never fires. Launch the program here instead.
            wsFocusBody = name: program: ''
              local created = hl.get_workspace("name:${name}") == nil
              hl.dispatch(hl.dsp.focus({ workspace = "name:${name}" }))
              if created then
                hl.dispatch(${execDsp program})
              end'';
            wsFocus = name: program: "function()\n${wsFocusBody name program}\nend";
            wsMove = name: ''hl.dsp.window.move({ workspace = "name:${name}" })'';

            # Occasional apps live behind SUPER + O ("open"), then a letter;
            # SHIFT + letter sends the active window there instead.
            appsSubmap = [
              {
                key = "S";
                name = "steam";
                desc = "Steam";
                program = steam;
              }
              {
                key = "B";
                name = "bambu-studio";
                desc = "Bambu Studio";
                program = bambu-studio;
              }
              {
                key = "O";
                name = "obsidian";
                desc = "Obsidian";
                program = obsidian;
              }
              {
                key = "X";
                name = "twitter";
                desc = "X";
                program = twitter;
              }
              {
                key = "P";
                name = "_1password";
                desc = "1Password";
                program = _1password;
              }
              {
                key = "F";
                name = "file-manager";
                desc = "File manager";
                program = fileManager;
              }
              {
                key = "M";
                name = "messaging";
                desc = "Messaging";
                program = messaging;
              }
            ];
            submapReset = ''hl.dispatch(hl.dsp.submap("reset"))'';
            focusDir = dir: ''hl.dsp.focus({ direction = "${dir}" })'';
            moveDir = dir: ''hl.dsp.window.move({ direction = "${dir}" })'';

            startupCommands = [
              "/run/wrappers/bin/gnome-keyring-daemon --start --components=secrets"

              # Wallpaper
              "${awww}-daemon"
              "${awww} img ${config.wallpaper} -t none"

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
                  inherit (monitor) scale;
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
                # Alt+Shift switches between English and Ukrainian. Keep the
                # international US variant only on the US layout.
                kb_layout = "us,ua";
                kb_variant = "altgr-intl,";
                kb_options = "ctrl:nocaps,lv3:ralt_switch,grp:alt_shift_toggle";
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

            workspace_rule = lib.mapAttrsToList (
              name: ws: { workspace = "name:${name}"; } // ws.extraRules
            ) cfg.workspaces;

            # MakerWorld launches Bambu Studio directly through its URI handler,
            # bypassing the workspace keybind. Route that window to the same workspace.
            window_rule = [
              {
                match.class = "^BambuStudio$";
                workspace = "name:bambu-studio";
              }
            ];

            # Blur behind the bar, launcher, notifications, OSD and power menu, so
            # their translucent backgrounds stay readable. ignore_alpha skips the
            # fully transparent space around Waybar's pills.
            layer_rule = [
              {
                match.namespace = "^(waybar|rofi|swaync-control-center|swaync-notification-window|swayosd|logout_dialog)$";
                blur = true;
                ignore_alpha = 0.3;
              }
            ];

            define_submap = {
              _args = [
                "open"
                (mkLuaInline (
                  "function()\n"
                  + lib.concatMapStrings (app: ''
                    hl.bind("${app.key}", function()
                    ${submapReset}
                    ${wsFocusBody app.name app.program}
                    end, { description = ${builtins.toJSON app.desc} })
                    hl.bind("SHIFT + ${app.key}", function()
                    ${submapReset}
                    hl.dispatch(${wsMove app.name})
                    end, { description = ${builtins.toJSON "Move window to ${app.desc}"} })
                  '') appsSubmap
                  + ''
                    hl.bind("Escape", hl.dsp.submap("reset"), { description = "Leave open menu" })
                    end''
                ))
              ];
            };

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

                # Resize (repeat) with SUPER + CTRL + arrows or H/J/K/L
                resizeBinds =
                  lib.concatMap
                    (
                      {
                        keys,
                        x,
                        y,
                      }:
                      map (
                        key:
                        mkBindOpts "SUPER + CTRL + ${key}"
                          "hl.dsp.window.resize({ x = ${toString x}, y = ${toString y}, relative = true })"
                          { repeating = true; }
                      ) keys
                    )
                    [
                      {
                        keys = [
                          "left"
                          "H"
                        ];
                        x = -40;
                        y = 0;
                      }
                      {
                        keys = [
                          "right"
                          "L"
                        ];
                        x = 40;
                        y = 0;
                      }
                      {
                        keys = [
                          "up"
                          "K"
                        ];
                        x = 0;
                        y = -40;
                      }
                      {
                        keys = [
                          "down"
                          "J"
                        ];
                        x = 0;
                        y = 40;
                      }
                    ];
              in
              moveWorkspaceToMonitor
              ++ [
                # Focus daily workspaces; the rest are in the "apps" submap
                (mkBind "SUPER + B" (wsFocus "browser" browser))
                (mkBind "SUPER + T" (wsFocus "terminal" terminal))
                (mkBind "SUPER + D" (wsFocus "discord" discord))
                (mkBind "SUPER + M" (wsFocus "music" music))
                (mkBind "SUPER + C" (wsFocus "herdr" herdr))
                (mkBind "SUPER + O" ''hl.dsp.submap("open")'')

                # Move active window to daily workspaces
                (mkBind "SUPER + SHIFT + B" (wsMove "browser"))
                (mkBind "SUPER + SHIFT + T" (wsMove "terminal"))
                (mkBind "SUPER + SHIFT + D" (wsMove "discord"))
                (mkBind "SUPER + SHIFT + M" (wsMove "music"))
                (mkBind "SUPER + SHIFT + C" (wsMove "herdr"))

                # Window actions
                (mkBind "SUPER + Q" "hl.dsp.window.close()")
                (mkBind "SUPER + V" ''hl.dsp.window.float({ action = "toggle" })'')
                (mkBind "SUPER + F" ''hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })'')
                (mkBind "SUPER + SHIFT + F" ''hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })'')
                (mkBind "SUPER + E" ''hl.dsp.layout("togglesplit")'')
                (mkBind "SUPER + Tab" ''hl.dsp.focus({ workspace = "previous" })'')
                (mkBind "SUPER + grave" "hl.dsp.window.cycle_next()")
                (mkBind "SUPER + SHIFT + grave" "hl.dsp.window.cycle_next({ next = false })")
                (mkBind "SUPER + bracketleft" ''hl.dsp.focus({ monitor = "-1" })'')
                (mkBind "SUPER + bracketright" ''hl.dsp.focus({ monitor = "+1" })'')
                (mkBind "SUPER + Return" (execDsp terminal))
                (mkBind "SUPER + Space" (execDsp launcher))
                (mkBind "SUPER + period" (execDsp emoji))
                (mkBind "SUPER + SHIFT + slash" (execDsp "${cheatSheet}"))
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
              ++ resizeBinds
              ++ lib.optional config.hyprlock.enable (mkBind "SUPER + Escape" (execDsp "loginctl lock-session"))
              ++ lib.optional config.swaync.enable (
                mkBind "SUPER + N" (
                  execDsp "${lib.getExe' config.services.swaync.package "swaync-client"} --toggle-panel --skip-wait"
                )
              )
              ++ lib.optional config.cliphist.enable (
                mkBind "SUPER + SHIFT + V" (execDsp (lib.getExe config.cliphist.picker))
              )
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
                # Each one is copied and saved to the pictures folder.
                (mkBind "Print" (execDsp "SLURP_RECTS= ${screenshot} copysave area"))
                (mkBind "SHIFT + Print" (execDsp "${screenshot} copysave active"))
                (mkBind "SUPER + Print" (execDsp "${screenshot} copysave output"))

                # Move and resize windows with SUPER + LMB/RMB and dragging
                (mkBindOpts "SUPER + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
                (mkBindOpts "SUPER + mouse:273" "hl.dsp.window.resize()" { mouse = true; })

                # Volume (repeat, works while locked)
                (mkBindOpts "XF86AudioRaiseVolume" (execDsp keyCmd.volumeUp) {
                  locked = true;
                  repeating = true;
                })
                (mkBindOpts "XF86AudioLowerVolume" (execDsp keyCmd.volumeDown) {
                  locked = true;
                  repeating = true;
                })
                (mkBindOpts "SUPER + XF86AudioRaiseVolume" (execDsp keyCmd.micUp) {
                  locked = true;
                  repeating = true;
                })
                (mkBindOpts "SUPER + XF86AudioLowerVolume" (execDsp keyCmd.micDown) {
                  locked = true;
                  repeating = true;
                })

                # Brightness (repeat, works while locked)
                (mkBindOpts "XF86MonBrightnessUp" (execDsp keyCmd.brightnessUp) {
                  locked = true;
                  repeating = true;
                })
                (mkBindOpts "XF86MonBrightnessDown" (execDsp keyCmd.brightnessDown) {
                  locked = true;
                  repeating = true;
                })

                # Mute + media (works while locked)
                (mkBindOpts "XF86AudioMute" (execDsp keyCmd.mute) {
                  locked = true;
                })
                (mkBindOpts "XF86AudioMicMute" (execDsp keyCmd.micMute) {
                  locked = true;
                })
                (mkBindOpts "XF86AudioPlay" (execDsp "${media} play-pause") { locked = true; })
                (mkBindOpts "XF86AudioPrev" (execDsp "${media} previous") { locked = true; })
                (mkBindOpts "XF86AudioNext" (execDsp "${media} next") { locked = true; })
                (mkBindOpts "XF86AudioStop" (execDsp "${media} stop") { locked = true; })
              ];
          };
      };

      # Polkit agent for prompts like 1Password's system-auth unlock
      # (fingerprint via the polkit-1 PAM stack).
      services.hyprpolkitagent.enable = true;
    })
  ];
}
