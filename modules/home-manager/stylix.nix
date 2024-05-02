{ ... }:
{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.stylix.homeManagerModules.stylix ];

  stylix = {
    image = /home/${config.username}/dotfiles/assets/wallpaper.png;
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";
    fonts.monospace = {
      name = "Hack Nerd Font Mono";
      package = pkgs.nerdfonts;
    };
    opacity.terminal = 0.85;
    targets = {
      helix.enable = false;
    };
  };
}
