{ pkgs, ... }:

{
  programs.nushell = {
    enable = true;
    extraConfig = ''
      $env.config = {
        show_banner: false,
      }

      # run neofetch on launch
      ${pkgs.neofetch}/bin/neofetch
    '';
  };
}
