{ lib, config, ... }:
let
  cfg = config.wlogout;
in
{
  options = {
    wlogout.enable = lib.mkEnableOption "wlogout" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.wlogout = {
      enable = config.wlogout.enable;
      layout = [
        {
          "label" = "lock";
          "action" = "loginctl lock-session";
          "text" = "Lock";
          "keybind" = "l";
        }
        {
          "label" = "hibernate";
          "action" = "systemctl hibernate";
          "text" = "Hibernate";
          "keybind" = "h";
        }
        {
          "label" = "logout";
          "action" = "loginctl kill-user $(whoami)";
          "text" = "Logout";
          "keybind" = "e";
        }
        {
          "label" = "suspend";
          "action" = "systemctl suspend";
          "text" = "Suspend";
          "keybind" = "u";
        }
        {
          "label" = "reboot";
          "action" = "systemctl reboot";
          "text" = "Reboot";
          "keybind" = "r";
        }
        {
          "label" = "shutdown";
          "action" = "systemctl poweroff";
          "text" = "Shutdown";
          "keybind" = "s";
        }
      ];
    };
  };
}
