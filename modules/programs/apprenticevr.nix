{
  flake.modules.homeManager.apprenticevr =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.apprenticevr ];
      };
    };
}
