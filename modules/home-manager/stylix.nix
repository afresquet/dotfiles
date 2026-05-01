{ ... }:
{ config, pkgs, inputs, ... }:
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
    targets = {
      helix.enable = false;
    };
  };
}
