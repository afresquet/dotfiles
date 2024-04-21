{ pkgs, ... }:

{
  programs.nushell = {
    enable = true;

    extraConfig = ''
      $env.config = {
        show_banner: false,
      }

      # run fastfetch on launch
      ${pkgs.fastfetch}/bin/fastfetch
    '';
  };
}
