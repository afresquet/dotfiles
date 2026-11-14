{
  flake.modules.homeManager.sd =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.sd ];
    };
}
