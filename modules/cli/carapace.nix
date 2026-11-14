{
  flake.modules.homeManager.carapace = _: {
    config = {
      programs.carapace = {
        enable = true;
      };
    };
  };
}
