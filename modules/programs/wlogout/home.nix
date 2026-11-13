{
  lib,
  config,
  pkgs,
  isLinux,
  ...
}:
let
  cfg = config.wlogout;
  c = config.lib.stylix.colors.withHashtag;
  wlogout = config.programs.wlogout.package;
  icons = "${wlogout}/share/wlogout/icons";

  # wlogout sizes buttons from pixel margins, so center two rows of three
  # 200px squares (20px apart) on the focused monitor. The CSS keeps each
  # button exactly that size: no padding, border counted in.
  launcher = pkgs.writeShellScriptBin "power-menu" ''
    read -r w h < <(${lib.getExe' config.wayland.windowManager.hyprland.finalPackage "hyprctl"} monitors -j |
      ${lib.getExe pkgs.jq} -r '.[] | select(.focused) | "\((.width / .scale) | floor) \((.height / .scale) | floor)"')
    x=$(( (w - (3 * 200 + 2 * 20)) / 2 ))
    y=$(( (h - (2 * 200 + 20)) / 2 ))
    exec ${lib.getExe wlogout} -b 3 -c 20 -r 20 -L "$x" -R "$x" -T "$y" -B "$y" -n "$@"
  '';
in
{
  options = {
    wlogout.enable = lib.mkEnableOption "wlogout power menu" // {
      default = isLinux;
    };
    wlogout.launcher = lib.mkOption {
      type = lib.types.package;
      default = launcher;
      readOnly = true;
      internal = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ launcher ];

    programs.wlogout = {
      enable = true;
      layout = [
        {
          label = "lock";
          action = "loginctl lock-session";
          text = "Lock";
          keybind = "l";
        }
        {
          label = "hibernate";
          action = "systemctl hibernate";
          text = "Hibernate";
          keybind = "h";
        }
        {
          label = "logout";
          action = "loginctl kill-user $(whoami)";
          text = "Logout";
          keybind = "e";
        }
        {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "u";
        }
        {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot";
          keybind = "r";
        }
        {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutdown";
          keybind = "s";
        }
      ];

      # Matches rofi and swaync: dark blurred backdrop, base01 cards with
      # 12px corners, blue accent on focus. Shut down is red on focus.
      style = ''
        * {
          background-image: none;
          box-shadow: none;
          font-family: "${config.stylix.fonts.monospace.name}";
          font-size: 16px;
        }

        window {
          background-color: alpha(${c.base00}, 0.6);
        }

        button {
          color: ${c.base04};
          min-width: 196px;
          min-height: 196px;
          padding: 0;
          background-color: alpha(${c.base01}, 0.92);
          border: 2px solid ${c.base02};
          border-radius: 16px;
          background-repeat: no-repeat;
          background-position: center 38%;
          background-size: 34%;
          outline-style: none;
        }

        button:focus,
        button:hover {
          background-color: ${c.base02};
          border-color: ${c.base0D};
          color: ${c.base05};
        }

        #shutdown:focus,
        #shutdown:hover {
          border-color: ${c.base08};
        }

        #lock { background-image: image(url("${icons}/lock.png")); }
        #hibernate { background-image: image(url("${icons}/hibernate.png")); }
        #logout { background-image: image(url("${icons}/logout.png")); }
        #suspend { background-image: image(url("${icons}/suspend.png")); }
        #reboot { background-image: image(url("${icons}/reboot.png")); }
        #shutdown { background-image: image(url("${icons}/shutdown.png")); }
      '';
    };
  };
}
