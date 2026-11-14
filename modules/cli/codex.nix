{
  flake.modules.homeManager.codex = _: {
    config = {
      programs.codex = {
        enable = true;

        mutableSettings = true;
      };
    };
  };
}
