{ lib, config, ... }:
let
  cfg = config.fish;
in
{
  options = {
    fish.enable = lib.mkEnableOption "fish" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;

      shellInit = ''
        set -g fish_greeting
      '';

      shellInitLast = config.terminal.onInit;
    };
  };
}
