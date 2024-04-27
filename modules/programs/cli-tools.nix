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
      wl-clipboard-rs
      wget
      wiki-tui
      youtube-dl
      grex
      # archives
      zip
      xz
      unzip
      p7zip
    ];
  };
}
