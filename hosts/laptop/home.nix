{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  btop.rocmSupport = true;

  hyprlock = {
    enable = true;
    fingerprint = true;
  };

  waybar.statsIcon = "";
}
