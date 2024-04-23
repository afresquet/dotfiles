{ pkgs, module }: pkgs.writeShellApplication {
  name = "nr";

  text = ''
    sudo nixos-rebuild "$1" --flake ~/dotfiles#${module}
  '';
}
