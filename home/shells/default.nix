{ pkgs, ... }:

{
  imports = [
    ./carapace.nix
    ./nushell.nix
    ./starship.nix
    ./zellij.nix
    ./zoxide.nix
  ];

  home.packages = with pkgs; [
    bash
    fish
    nushell
    zsh
  ];

  home.sessionVariables = {
    EDITOR = "hx";
    BROWSER = "brave";
    TERMINAL = "alacritty";
  };
}
