{ ... }: {
  imports = [
    ./../../home
  ];

  # Programs
  alacritty.enable = true;
  direnv.enable = true;
  git.enable = true;
  helix.enable = true;
  hyprland.monitors = [
    {
      name = "eDP-1";
      width = 2256;
      height = 1504;
      refreshRate = 59.93;
      x = 0;
      y = 0;
      scale = 2;
      enable = true;
    }
  ];
  mako.enable = true;
  waybar.enable = true;
  wlogout.enable = true;
  wpaperd.enable = true;

  # Services
  touchpad.enable = true;

  # Shells
  carapace.enable = true;
  starship.enable = true;
  zellij.enable = true;
  zoxide.enable = true;
}

