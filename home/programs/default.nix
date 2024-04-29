{ ... }: {
  imports = [
    ./alacritty.nix
    ./cli-tools.nix
    ./direnv.nix
    ./git.nix
    ./helix.nix
    ./mako.nix
    ./obs-studio.nix
    ./waybar
    ./wezterm
    ./wlogout.nix
  ];
}
