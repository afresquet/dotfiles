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
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      home.packages = [ pkgs.nh ];

      home.shellAliases =
        let
          nh = lib.getExe pkgs.nh;
          local = "${config.home.homeDirectory}/dotfiles";
        in
        {
          # nix caches the GitHub tarball; --refresh makes it fetch the latest commit.
          noss = "${nh} os switch ${repo} -- --refresh";
          nost = "${nh} os test ${repo} -- --refresh";
          nosb = "${nh} os boot ${repo} -- --refresh";
          ndws = "${nh} darwin switch ${repo} -- --refresh";
          nhms = "${nh} home switch ${repo} -- --refresh";
          # The same against the local checkout, to try changes before pushing them.
          nossl = "${nh} os switch ${local}";
          nostl = "${nh} os test ${local}";
          nosbl = "${nh} os boot ${local}";
          ndwsl = "${nh} darwin switch ${local}";
          nhmsl = "${nh} home switch ${local}";
          nca = "${nh} clean all --no-gcroots";
        };
    };
}
