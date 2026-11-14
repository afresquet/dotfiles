{
  flake.modules.homeManager.coreutils =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.uutils-coreutils-noprefix ];
      };
    };
}
