{ lib, config, pkgs, ... }: {
  options = {
    cli-tools.enable = lib.mkEnableOption "CLI tools";
  };

  config = {
    packages = with pkgs; lib.mkIf config.cli-tools.enable [
      bat
      eza
      fastfetch
      fd
      fzf
      btop
      jq
      ripgrep
      tokei
      uutils-coreutils
      wget
      wiki-tui
      youtube-dl
      # archives
      zip
      xz
      unzip
      p7zip
    ];
  };
}
