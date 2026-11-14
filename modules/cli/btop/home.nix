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
    btop = {
      enable = lib.mkEnableOption "btop" // {
        default = true;
      };
      rocmSupport = lib.mkEnableOption "btop ROCm (AMD GPU) support";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.btop = {
      enable = true;
      package = pkgs.btop.override { inherit (cfg) rocmSupport; };
    };
  };
}
