{
  flake.modules.homeManager.coreutils =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.uutils-coreutils-noprefix ];
    };
}
