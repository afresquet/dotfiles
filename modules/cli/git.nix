{
  flake.modules.homeManager.git =
    { lib, config, ... }:
    let
      cfg = config.git;
    in
    {
      options = {
        git = {
          email = lib.mkOption { type = lib.types.str; };
          signingKey = lib.mkOption { type = lib.types.str; };
        };
      };

      config = {
        programs.git = {
          enable = true;
          settings = {
            user = {
              name = config.home.username;
              inherit (cfg) email;
            };
            init.defaultBranch = "master";
            core.editor = lib.getExe config.programs.helix.package;
            push.autoSetupRemote = true;
          };
          signing = {
            key = cfg.signingKey;
            format = "ssh";
            signByDefault = true;
          };
        };
        programs.difftastic = {
          enable = true;
          git.enable = true;
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
    };
}
