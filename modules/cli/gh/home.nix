{ lib, config, ... }:
let
  cfg = config.gh;
in
{
  options = {
    gh.enable = lib.mkEnableOption "GitHub CLI" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gh = {
      enable = true;
      settings.git_protocol = "ssh";
    };
  };
}
