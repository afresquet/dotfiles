{
  flake.modules.homeManager.alacritty = _: {
    config = {
      programs.alacritty.enable = true;
    };
  };
}
