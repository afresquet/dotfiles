{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.zip;
in
{
  options = {
    zip.enable = lib.mkEnableOption "zip" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      zip
      xz
      unzip
      p7zip
    ];
  };
}
