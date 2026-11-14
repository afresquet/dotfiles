{
  flake.modules.homeManager.direnv = _: {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
