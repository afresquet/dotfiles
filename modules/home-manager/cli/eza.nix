{ lib, config, ... }:
let
  cfg = config.eza;
in
{
  options = {
    eza.enable = lib.mkEnableOption "eza" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.eza.enable = true;

    home.shellAliases =
      let
        eza = lib.getExe config.programs.eza.package;
      in
      {
        lt = "${eza} --tree";
      };
  };
}
