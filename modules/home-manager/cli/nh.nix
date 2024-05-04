{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.nh;
in
{
  options = {
    nh.enable = lib.mkEnableOption "nh" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.nh ];

    home.shellAliases =
      let
        nh = lib.getExe pkgs.nh;
        flake = "~/dotfiles";
      in
      {
        noss = "${nh} os switch ${flake}";
        nost = "${nh} os test ${flake}";
        nosb = "${nh} os boot ${flake}";
        nhms = "${nh} home switch ${flake}";
      };
  };
}
