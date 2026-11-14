{
  flake.modules.homeManager.jq =
    {
      pkgs,
      ...
    }:
    {
      config = {
        programs.jq.enable = true;

        home.packages = [ pkgs.jqp ];
      };
    };
}
