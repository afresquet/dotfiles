{ ... }:
{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.stylix.homeModules.stylix ];

  stylix = {
    enable = true;
    image = config.wallpaper;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";
    fonts.monospace = {
      name = "Hack Nerd Font Mono";
      package = pkgs.nerd-fonts.hack;
    };
    opacity.terminal = lib.mkDefault 0.85;
    # GTK icon theme; without one, apps like swaync show broken-icon
    # placeholders. Same theme rofi uses.
    icons = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
    targets = {
      helix.enable = false;
    };
  };
}
