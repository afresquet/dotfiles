{ lib, config, pkgs, ... }:
let
  enable = config.home-manager.users.${config.username}.cli-tools.enable;
in
{
  packages = with pkgs; lib.mkIf enable [
    fastfetch
    fd
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
}
