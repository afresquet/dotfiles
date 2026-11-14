{
  flake.modules.homeManager.gh = _: {
    programs.gh = {
      enable = true;
      settings.git_protocol = "ssh";
    };
  };
}
