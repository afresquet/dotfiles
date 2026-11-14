{
  flake.modules.homeManager.sd =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.sd ];
      };
    };
}
