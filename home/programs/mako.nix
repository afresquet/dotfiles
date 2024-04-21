{ lib, config, ... }: {
  options = {
    mako.enable = lib.mkEnableOption "Mako";
  };

  config = {
    services.mako = with config.colorScheme.palette; {
      enable = config.mako.enable;
      backgroundColor = "#${base01}";
      borderColor = "#${base0E}";
      borderRadius = 5;
      borderSize = 2;
      textColor = "#${base04}";
      layer = "overlay";
    };
  };
}
