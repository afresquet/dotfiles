{
  flake.modules.homeManager.tokei =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.tokei ];
    };
}
