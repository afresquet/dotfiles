{ pkgs, ... }: {
  programs.fish = {
    enable = true;

    shellInit = ''
      set -g fish_greeting
    '';

    shellInitLast = ''
      ${pkgs.fastfetch}/bin/fastfetch
    '';
  };
}
