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
            helix = lib.getExe config.editor;
          in
          {
            edit = "${helix} -- {{filename}}";
            editAtLine = "${helix} -- {{filename}}:{{line}}";
            editAtLineAndWait = "${helix} -- {{filename}}:{{line}}";
            openDirInEditor = "${helix} -- {{dir}}";
            editInTerminal = true;
          };
      };
    };

    home.shellAliases = {
      lg = lib.getExe config.programs.lazygit.package;
    };
  };
}
