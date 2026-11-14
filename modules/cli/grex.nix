{
  flake.modules.homeManager.grex =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.grex ];
    };
}
