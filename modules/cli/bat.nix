{
  flake.modules.homeManager.bat = _: {
    config = {
      programs.bat.enable = true;
    };
  };
}
