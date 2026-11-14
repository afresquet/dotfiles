{
  flake.modules.homeManager.btop =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.btop;
    in
    {
      options = {
        btop = {
          rocmSupport = lib.mkEnableOption "btop ROCm (AMD GPU) support";
        };
      };

      config = {
        programs.btop = {
          enable = true;
          package = pkgs.btop.override { inherit (cfg) rocmSupport; };
        };
      };
    };
}
