{
  imports = [ ../settings.nix ];

  hostname = "Alvaro-Laptop";

  monitors = [
    {
      name = "eDP-1";
      width = 2256;
      height = 1504;
      refreshRate = 59.93;
      x = 0;
      y = 0;
      scale = "auto";
      enable = true;
    }
  ];
}
