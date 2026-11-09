{
  imports = [
    ../home.nix
    ./settings.nix
  ];

  herdr-desktop.enable = true;

  btop.rocmSupport = true;

  hyprlock = {
    enable = true;
    fingerprint = true;
  };

  waybar.statsIcon = "<span size='x-large'>󰌢</span>";
}
