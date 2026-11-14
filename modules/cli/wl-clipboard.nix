{
  flake.modules.homeManager.wl-clipboard =
    {
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [ pkgs.wl-clipboard-rs ];
      };
    };
}
