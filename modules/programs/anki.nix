{
  flake.modules.homeManager.anki = _: {
    config = {
      programs.anki.enable = true;
    };
  };
}
