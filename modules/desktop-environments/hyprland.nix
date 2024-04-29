{ config, ... }:
let
  enable = config.home-manager.users.${config.username}.hyprland.enable;
in
{
  programs.hyprland.enable = enable;
  xdg.portal.enable = enable;
}
