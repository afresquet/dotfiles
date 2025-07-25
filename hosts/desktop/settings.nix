{
  imports = [ ../settings.nix ];

  hostname = "Alvaro-Desktop";

  monitors = [
    {
      name = "DP-1";
      width = 1920;
      height = 1080;
      refreshRate = 60.0;
      x = 0;
      y = 0;
      enable = true;
    }

    {
      name = "HDMI-A-1";
      width = 3840;
      height = 2160;
      refreshRate = 60.0;
      x = 1920;
      y = 0;
      enable = true;
    }
  ];
}
