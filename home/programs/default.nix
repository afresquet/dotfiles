{ pkgs, ... }:

{
  imports = [
    ./git.nix
    ./helix.nix
    ./nushell.nix
    ./starship.nix
    ./wezterm.nix
    ./zoxide.nix
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
