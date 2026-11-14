{
  flake.modules.homeManager.telegram-desktop =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.telegram-desktop ];
    };
}
