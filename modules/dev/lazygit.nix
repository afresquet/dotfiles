{
  flake.modules.homeManager.lazygit =
    { lib, config, ... }:
    {
      config = {
        programs.lazygit = {
          enable = true;

          settings = {
            gui = {
              nerdFontsVersion = "3";
            };

            os =
              let
                editor = lib.getExe config.programs.helix.package;
              in
              {
                edit = "${editor} -- {{filename}}";
                editAtLine = "${editor} -- {{filename}}:{{line}}";
                editAtLineAndWait = "${editor} -- {{filename}}:{{line}}";
                openDirInEditor = "${editor} -- {{dir}}";
                editInTerminal = true;
              };
          };
        };

        home.shellAliases = {
          lg = lib.getExe config.programs.lazygit.package;
        };
      };
    };
}
