{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.tokei;
in
{
  options = {
    tokei.enable = lib.mkEnableOption "tokei" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable { home.packages = [ pkgs.tokei ]; };
}
