{
  flake.modules.homeManager.fd =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.fd ];
      };
    };
}
