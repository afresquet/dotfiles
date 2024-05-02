# https://github.com/nix-community/home-manager/pull/5363
{ pkgs, lib, config, ... }:
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
      default = {
        modules = [
          "title"
          "separator"
          "os"
          "host"
          "kernel"
          "uptime"
          "packages"
          "shell"
          "display"
          "de"
          "wm"
          "wmtheme"
          "theme"
          "icons"
          "font"
          "cursor"
          "terminal"
          "terminalfont"
          "cpu"
          "gpu"
          "memory"
          "swap"
          "disk"
          "localip"
          "battery"
          "poweradapter"
          "locale"
          "break"
          "colors"
        ];
      };
      example = lib.literalExpression ''
        {
          logo = {
            source = "nixos_small";
            padding = {
              right = 1;
            };
          };
          display = {
            binaryPrefix = "si";
            color = "blue";
            separator = "  ";
          };
          modules = [
            {
              type = "datetime";
              key = "Date";
              format = "{1}-{3}-{11}";
            }
            {
              type = "datetime";
              key = "Time";
              format = "{14}:{17}:{20}";
            }
            "break"
            "player"
            "media"
          ];
        };
      '';
      description = ''
        Configuration written to {file}`$XDG_CONFIG_HOME/fastfetch/config.jsonc`.
        See <https://github.com/fastfetch-cli/fastfetch/wiki/Json-Schema>
        for the documentation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile."fastfetch/config.jsonc".source =
      jsonFormat.generate "config.jsonc" cfg.settings;
  };
}
