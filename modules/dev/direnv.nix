{
  flake.modules.homeManager.direnv = _: {
    config = {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
    };
  };
}
