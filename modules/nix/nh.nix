{ config, ... }:
let
  inherit (config.meta) repo;
in
{
  flake.modules.nixos.nh.programs.nh = {
    enable = true;
    flake = repo;
    clean = {
      enable = true;
      extraArgs = "--keep-since 4d --keep 3 --no-gcroots";
    };
  };

  flake.modules.homeManager.nh =
    { lib, pkgs, ... }:
    {
      home.packages = [ pkgs.nh ];

      home.shellAliases =
        let
          nh = lib.getExe pkgs.nh;
        in
        {
          noss = "${nh} os switch ${repo}";
          nost = "${nh} os test ${repo}";
          nosb = "${nh} os boot ${repo}";
          ndws = "${nh} darwin switch ${repo}";
          nhms = "${nh} home switch ${repo}";
          nca = "${nh} clean all --no-gcroots";
        };
    };
}
