{
  flake.modules.homeManager.gitui = _: {
    config = {
      programs.gitui = {
        enable = true;
        keyConfig = builtins.readFile ./key_bindings.ron;
      };
    };
  };
}
