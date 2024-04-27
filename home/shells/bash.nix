{ pkgs, ... }: {
  programs.bash = {
    enable = true;

    initExtra = ''
      ${pkgs.fastfetch}/bin/fastfetch
    '';
  };
}
