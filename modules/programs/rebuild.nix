{ pkgs, module }: pkgs.writeShellApplication {
  name = "nix-rebuild";

  text = ''
    sudo nixos-rebuild "$1" --flake ~/dotfiles#${module}
  '';
}
