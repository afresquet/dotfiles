{
  flake.modules.homeManager.fzf = _: {
    config = {
      programs.fzf.enable = true;
    };
  };
}
