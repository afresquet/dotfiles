{
  flake.modules.homeManager.agenix =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.agenix ];
      };
    };
}
