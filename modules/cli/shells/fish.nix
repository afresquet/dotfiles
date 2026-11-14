{
  flake.modules.homeManager.fish = _: {
    config = {
      programs.fish = {
        enable = true;

        shellInit = ''
          set -g fish_greeting
        '';
      };
    };
  };
}
