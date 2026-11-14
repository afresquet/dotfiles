{
  flake.modules.homeManager.wl-clipboard =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.wl-clipboard-rs ];
    };
}
