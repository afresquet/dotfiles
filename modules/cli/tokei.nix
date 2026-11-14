{
  flake.modules.homeManager.tokei =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.tokei ];
      };
    };
}
