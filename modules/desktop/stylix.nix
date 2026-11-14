{ inputs, config, ... }:
let
  inherit (config) meta;
in
{
  flake.modules.homeManager.stylix =
    { lib, pkgs, ... }:
    {
      imports = [ inputs.stylix.homeModules.stylix ];

      stylix = {
        enable = true;
        image = meta.wallpaper;
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
          # The rofi aspect themes rofi from Stylix's colors itself; its stock
          # theme is plain. Off here rather than in that aspect so homes without
          # rofi (the Macs) don't load the target either: it defines the renamed
          # `programs.rofi.font` and warns.
          rofi.enable = false;
        };
      };
    };
}
