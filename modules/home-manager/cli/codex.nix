{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.codex;
in
{
  options.codex.enable = lib.mkEnableOption "Codex" // {
    default = false;
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      programs.codex = {
        enable = true;

        mutableSettings = true;
      };
    })

    (lib.mkIf (!cfg.enable) {
      assertions = [
        {
          assertion = pkgs.codex.version == "0.167.0";
          message = "codex is now ${pkgs.codex.version} (0.167.0 failed to build): set codex.enable back to true in modules/home-manager/cli/codex.nix and remove this assertion";
        }
      ];
    })
  ];
}
