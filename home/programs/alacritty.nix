{ lib, config, pkgs, ... }: {
  options = {
    alacritty.enable = lib.mkEnableOption "Alacritty";
  };

  config = {
    programs.alacritty = {
      enable = true;
      settings = {
        window.opacity = 0.85;
        font.normal = {
          family = "Hack Nerd Font Mono";
          style = "Regular";
        };
        shell.program = "${pkgs.nushell}/bin/nu";
        colors = with config.colorScheme.palette; {
          bright = {
            black = "0x${base00}";
            blue = "0x${base0D}";
            cyan = "0x${base0C}";
            green = "0x${base0B}";
            magenta = "0x${base0E}";
            red = "0x${base08}";
            white = "0x${base06}";
            yellow = "0x${base09}";
          };
          cursor = {
            cursor = "0x${base06}";
            text = "0x${base06}";
          };
          normal = {
            black = "0x${base00}";
            blue = "0x${base0D}";
            cyan = "0x${base0C}";
            green = "0x${base0B}";
            magenta = "0x${base0E}";
            red = "0x${base08}";
            white = "0x${base06}";
            yellow = "0x${base0A}";
          };
          primary = {
            background = "0x${base00}";
            foreground = "0x${base06}";
          };
        };
      };
    };
  };
}
