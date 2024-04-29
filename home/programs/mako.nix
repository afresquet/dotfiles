{ lib, config, ... }: {
  options = {
    mako.enable = lib.mkEnableOption "Mako";
  };

  config = {
    services.mako = {
      enable = config.mako.enable;
      borderRadius = 5;
      borderSize = 2;
      layer = "overlay";
    };
  };
}
