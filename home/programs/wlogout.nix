{ ... }:

{
  programs.wlogout = {
    enable = true;
    layout = [
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
}
