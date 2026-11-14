{
  flake.modules.homeManager.agenix =
    { pkgs, ... }:
    {
      home.packages = [ pkgs.agenix ];
    };
}
