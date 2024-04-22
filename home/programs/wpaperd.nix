{ lib, config, ... }: {
  options = {
    wpaperd.enable = lib.mkEnableOption "wpaperd";
  };

  config =
    let
      path = ./assets/wallpaper.png;
      submodules = map
        (m:
          {
            ${m.name} = { inherit path; };
          }
        )
        (config.monitors);
    in
    {
      programs.wpaperd = {
        enable = config.wpaperd.enable;
        # https://github.com/danyspin97/wpaperd#wallpaper-configuration
        settings = lib.attrsets.mergeAttrsList submodules;
      };
    };
}
