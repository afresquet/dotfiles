{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.btop;
in
{
  options = {
    btop.enable = lib.mkEnableOption "btop" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.btop = {
      enable = true;
      package = pkgs.btop.override { rocmSupport = true; };
    };
  };
}
