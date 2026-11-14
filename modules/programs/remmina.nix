{
  flake.modules.homeManager.remmina =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.remmina ];
      };
    };
}
