{ lib, config, ... }: {
  options = {
    wpaperd.enable = lib.mkEnableOption "wpaperd";
  };

  config =
    let
      path = ./assets/wallpaper.png;
    in
    {
      programs.wpaperd = {
        enable = config.wpaperd.enable;
        # https://github.com/danyspin97/wpaperd#wallpaper-configuration
        settings = {
          DP-1 = {
            inherit path;
          };
          HDMI-A-1 = {
            inherit path;
          };
        };
      };
    };
}
