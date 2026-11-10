{ lib, config, ... }:
let
  cfg = config.lazygit;
in
{
  options = {
    lazygit.enable = lib.mkEnableOption "lazygit" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;

      settings = {
        gui = {
          nerdFontsVersion = "3";
        };

        os =
          let
            editor = lib.getExe config.editor;
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
}
