{ pkgs, font-awesome-bump,  ... }:

{
  imports = [
    ./alacritty.nix
    ./direnv.nix
    ./git.nix
    ./gitui
    ./helix.nix
    ./mako.nix
    ./waybar.nix
    ./wezterm
    ./wlogout.nix
    ./wpaperd.nix
  ];

  home.packages = with pkgs; [
    _1password-gui
    bat
    blender
    bottles
    brave
    cura
    discord
    docker
    fd
    ffmpeg
    font-awesome-bump.font-awesome
    fzf
    gimp
    go
    btop
    insomnia
    just
    jq
    lutris
    maestral
    mullvad-vpn
    gnome.nautilus
    neofetch
    nerdfonts
    obs-studio
    obsidian # electron vulnerability
    prismlauncher
    probe-rs
    prusa-slicer
    ripgrep
    rpi-imager
    sniffnet
    tokei
    trunk
    uutils-coreutils
    vlc
    cinnamon.warpinator
    wget
    wiki-tui
    youtube-dl
  ]; 
}
