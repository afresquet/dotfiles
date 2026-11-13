{ lib, config, ... }:
let
  cfg = config.fastfetch;
in
{
  options = {
    fastfetch.enable = lib.mkEnableOption "Fastfetch" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fastfetch.enable = true;

    home.shellAliases = {
      ff = lib.getExe config.programs.fastfetch.package;
    };
  };
}
