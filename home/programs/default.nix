{ pkgs, ... }:

{
  imports = [
    ./alacritty.nix
    ./git.nix
    ./gitui
    ./helix.nix
    ./mako.nix
    ./wezterm
  ];

  home.packages = with pkgs; [
    _1password
    bacon
    bat
    blender
    bottles
    brave
    cargo-binstall
    cargo-espflash
    cargo-expand
    cargo-generate
    cargo-info
    cargo-show-asm
    cargo-shuttle
    cargo-watch
    cura
    espup
    discord
    docker
    dropbox
    fd
    ffmpeg
    font-awesome
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
    probe-rs
    prusa-slicer
    ripgrep
    rpi-imager
    rustup
    sniffnet
    steam
    tokei
    trunk
    uutils-coreutils
    vlc
    cinnamon.warpinator
    wayland-logout
    wget
    wiki-tui
    youtube-dl
  ]; 
}
