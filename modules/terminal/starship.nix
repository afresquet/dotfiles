{
  flake.modules.homeManager.starship = _: {
    programs.starship = {
      enable = true;

      settings.add_newline = true;
    };
  };
}
