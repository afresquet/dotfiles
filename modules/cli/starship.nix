{
  flake.modules.homeManager.starship = _: {
    config = {
      programs.starship = {
        enable = true;

        settings = {
          add_newline = true;
        };
      };
    };
  };
}
