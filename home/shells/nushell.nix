{ pkgs, ... }:

{
  programs.nushell = {
    enable = true;

    environmentVariables = {
      EDITOR = "${pkgs.helix}/bin/hx";
    };

    extraConfig = ''
      $env.config = {
        show_banner: false,
      }

      # run fastfetch on launch
      ${pkgs.fastfetch}/bin/fastfetch
    '';
  };
}
