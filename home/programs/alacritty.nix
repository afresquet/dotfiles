{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.85;
      font.normal = {
        family = "Hack Nerd Font Mono";
        style = "Regular";
      };
      shell.program = "${pkgs.nushell}/bin/nu";
    };
  };
}
