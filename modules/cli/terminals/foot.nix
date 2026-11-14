{
  flake.modules.homeManager.foot = _: {
    config = {
      programs.foot.enable = true;
    };
  };
}
