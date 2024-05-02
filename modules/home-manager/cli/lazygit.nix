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

  config = lib.mkIf cfg.enable { programs.lazygit.enable = true; };
}
