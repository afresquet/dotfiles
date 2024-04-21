{ pkgs, ... }:

{
  programs.nushell.extraConfig = ''
    $env.config = {
      show_banner: false,
    }

    # run fastfetch on launch
    ${pkgs.fastfetch}/bin/fastfetch
  '';
}
