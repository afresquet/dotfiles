{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.zsh;
in
{
  options = {
    zsh.enable = lib.mkEnableOption "zsh" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      initExtra = ''
        ${pkgs.fastfetch}/bin/fastfetch
      '';
    };
  };
}
