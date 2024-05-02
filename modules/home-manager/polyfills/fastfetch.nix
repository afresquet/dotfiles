# https://github.com/nix-community/home-manager/pull/5363
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.programs.fastfetch;
  jsonFormat = pkgs.formats.json { };
in
{
  options.programs.fastfetch = {
    enable = lib.mkEnableOption "Fastfetch";

    package = lib.mkPackageOption pkgs "fastfetch" { };

    settings = lib.mkOption {
      type = jsonFormat.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."fastfetch/config.jsonc" = lib.mkIf (cfg.settings != { }) {
      source = jsonFormat.generate "config.jsonc" cfg.settings;
    };
  };
}
