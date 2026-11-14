{
  flake.modules.homeManager.wget =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.wget ];
      };
    };
}
