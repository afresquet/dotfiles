{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;
    settings = {
      window.opacity = 0.95;
      font.normal = {
        family = "Hack Nerd Font Mono";
        style = "Regular";
      };
      shell.program = "${pkgs.nushell}/bin/nu";
    };
  };
}
