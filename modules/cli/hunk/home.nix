{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.hunk;
in
{
  imports = [ inputs.hunk.homeManagerModules.default ];

  options.hunk.enable = lib.mkEnableOption "Hunk" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    programs.hunk = {
      enable = true;
      package = pkgs.hunk;
      enableClaudeIntegration = true;
    };
  };
}
