{ lib, config, ... }:
let
  cfg = config.git;
in
{
  options = {
    git = {
      enable = lib.mkEnableOption "git" // {
        default = true;
      };
      email = lib.mkOption { type = lib.types.str; };
      signingKey = lib.mkOption { type = lib.types.str; };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = config.username;
      userEmail = cfg.email;
      extraConfig = {
        init.defaultBranch = "main";
        core.editor = config.editor.path;
        user.signingkey = cfg.signingKey;
        gpg.format = "ssh";
        commit.gpgsign = true;
        push.autoSetupRemote = true;
      };
      delta = {
        enable = true;
        options = {
          navigate = true;
          light = false;
        };
      };
    };
  };
}
