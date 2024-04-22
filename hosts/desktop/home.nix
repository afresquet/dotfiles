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
      name = "DP-1";
      width = 1920;
      height = 1080;
      refreshRate = 59.96;
      x = 0;
      y = 0;
      enable = true;
    }

    {
      name = "HDMI-1";
      width = 1920;
      height = 1080;
      refreshRate = 59.96;
      x = 1920;
      y = 0;
      enable = true;
    }
  ];
  mako.enable = true;
  waybar.enable = true;
  wlogout.enable = true;
  wpaperd.enable = true;

  # Shells
  carapace.enable = true;
  starship.enable = true;
  zellij.enable = true;
  zoxide.enable = true;
}

