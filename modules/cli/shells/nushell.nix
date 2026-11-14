{
  flake.modules.homeManager.nushell =
    { config, ... }:
    {
      config = {
        programs.nushell = {
          enable = true;

          extraConfig = ''
            $env.config = {
              show_banner: false,
            }
          '';

          loadSessionVariables = true;

          shellAliases = config.home.shellAliases;
        };
      };
    };
}
