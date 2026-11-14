{
  flake.modules.homeManager.telegram-desktop =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.telegram-desktop ];
      };
    };
}
