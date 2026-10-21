{ lib, config, ... }:
let
  cfg = config.copilot;
in
{
  options.copilot.enable = lib.mkEnableOption "GitHub Copilot CLI" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    programs.github-copilot-cli.enable = true;

    allowedUnfree = [ "github-copilot-cli" ];
  };
}
