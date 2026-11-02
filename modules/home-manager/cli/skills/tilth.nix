{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.skills.tilth;
in
{
  options.skills.tilth.enable = lib.mkEnableOption "Tilth skill" // {
    default = config.skills.enable;
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.tilth ];

    skills.sources.tilth = "${inputs.skills.tilth}/skills/SKILL.md";
  };
}
