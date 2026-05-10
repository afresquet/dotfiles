{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  btop.rocmSupport = true;

  waybar.statsIcon = "";
}
