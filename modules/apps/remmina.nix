{
  flake.modules.homeManager.remmina =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.remmina ];
    };
}
