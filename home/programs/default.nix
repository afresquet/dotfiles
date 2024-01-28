{ pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./git.nix
    ./helix.nix
    ./wezterm
  ];

  home.packages = with pkgs; [
    _1password
    bat
    blender
    bottles
    brave
    cargo-shuttle
    uutils-coreutils
    discord
    docker
    dropbox
    fd
    ffmpeg
    fzf
    gimp
    go
    htop
    insomnia
    just
    jq
    lutris
    mullvad-vpn
    neofetch
    nerdfonts
    obs-studio
    # obsidian # electron vulnerability
    prismlauncher
    prusa-slicer
    ripgrep
    rpi-imager
    rustup
    sniffnet
    steam
    tokei
    vlc
    cinnamon.warpinator
    wget
    wiki-tui
    youtube-dl
  ]; 
}
