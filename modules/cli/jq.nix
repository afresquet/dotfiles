{
  flake.modules.homeManager.jq =
    { pkgs, ... }:
    {
      programs.jq.enable = true;

      home.packages = [ pkgs.jqp ];
    };
}
