{
  flake.modules.homeManager.insomnia =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.insomnia ];
    };
}
