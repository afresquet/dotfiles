{
  flake.modules.homeManager.yazi = _: {
    config = {
      programs.yazi = {
        enable = true;
        shellWrapperName = "y";
      };
    };
  };
}
