{
  flake.modules.homeManager.insomnia =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.insomnia ];
      };
    };
}
