{
  flake.modules.homeManager.obs-studio = _: {
    config = {
      programs.obs-studio.enable = true;
    };
  };
}
