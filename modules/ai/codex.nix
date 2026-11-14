{
  flake.modules.homeManager.codex = _: {
    programs.codex = {
      enable = true;

      mutableSettings = true;
    };
  };
}
