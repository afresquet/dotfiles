{
  flake.modules.homeManager.herdr-desktop =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.herdr-desktop;
    in
    {

      # Exposed so other modules (the Hyprland workspace bind) can lib.getExe it.
      options.herdr-desktop.package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.herdr-desktop.override { herdr-core = config.herdr.corePackage; };
        readOnly = true;
        internal = true;
      };

      # herdr-core comes from the cli herdr module.
      config = {
        home.packages = [ cfg.package ];
      };
    };
}
