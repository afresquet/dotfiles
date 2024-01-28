{ pkgs, ... }:

{
  imports = [
    ./carapace.nix
    ./nushell.nix
    ./starship.nix
    ./zoxide.nix
  ];

  home.packages = with pkgs; [
    bash
    fish
    zsh
  ];

  home.sessionVariables = {
    EDITOR = "hx";
    BROWSER = "brave";
    TERMINAL = "wezterm";
  };
}
