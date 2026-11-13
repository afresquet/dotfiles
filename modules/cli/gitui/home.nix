{ lib, config, ... }:
let
  cfg = config.gitui;
in
{
  options = {
    gitui.enable = lib.mkEnableOption "GitUI" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gitui = {
      enable = true;
      keyConfig = builtins.readFile ./key_bindings.ron;
    };
  };
}
