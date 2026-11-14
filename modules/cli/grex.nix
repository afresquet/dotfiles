{
  flake.modules.homeManager.grex =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.grex ];
      };
    };
}
