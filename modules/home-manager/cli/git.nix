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
        init.defaultBranch = "master";
        core.editor = lib.getExe config.editor;
        user.signingkey = cfg.signingKey;
        gpg.format = "ssh";
        commit.gpgsign = true;
        push.autoSetupRemote = true;
      };
      difftastic.enable = true;
    };

    home.shellAliases =
      let
        git = lib.getExe config.programs.git.package;
        gw = "${git} worktree";
      in
      rec {
        ga = "${git} add";
        gaa = "${ga} .";
        gb = "${git} branch";
        gba = "${gb} --all";
        gbd = "${gb} -D";
        gc = "${git} commit";
        gca = "${gc} --amend -C HEAD";
        gco = "${git} checkout";
        gd = "${git} diff -w";
        gds = "${gd} --staged";
        gl = "${git} log --all --graph --format=oneline";
        gld = "${gl} -p --ext-diff";
        gp = "${git} push";
        gpf = "${gp} --force-with-lease";
        gpl = "${git} pull";
        gplr = "${gpl} --rebase";
        gr = "${git} restore";
        gra = "${git} rebase --abort";
        grc = "${git} rebase --continue";
        grs = "${gr} --staged";
        gs = "${git} status";
        gsh = "${git} stash";
        gsha = "${gsh} apply";
        gshp = "${gsh} pop";
        gwa = "${gw} add";
        gwl = "${gw} list";
        gwr = "${gw} remove";
      };
  };
}
