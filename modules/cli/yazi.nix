{
  flake.modules.homeManager.yazi = _: {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
    };
  };
}
