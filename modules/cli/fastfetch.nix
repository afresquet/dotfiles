{
  flake.modules.homeManager.fastfetch =
    { lib, config, ... }:
    {
      config = {
        programs.fastfetch.enable = true;

        home.shellAliases = {
          ff = lib.getExe config.programs.fastfetch.package;
        };
      };
    };
}
