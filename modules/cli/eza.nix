{
  flake.modules.homeManager.eza =
    { lib, config, ... }:
    {
      config = {
        programs.eza = {
          enable = true;
          icons = "auto";
          git = true;
          extraOptions = [ "--group-directories-first" ];
        };

        home.shellAliases =
          let
            eza = lib.getExe config.programs.eza.package;
          in
          {
            lt = "${eza} --tree";
          };
      };
    };
}
