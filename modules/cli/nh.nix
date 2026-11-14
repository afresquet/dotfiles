{ self, ... }:
{
  flake.modules.nixos.nh =
    { config, ... }:
    {
      imports = [ self.modules.nixos.primary-user ];

      config = {
        programs.nh = {
          enable = true;
          flake = "${config.users.users.${config.system.primaryUser}.home}/dotfiles";
          clean = {
            enable = true;
            extraArgs = "--keep-since 4d --keep 3 --no-gcroots";
          };
        };
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
      config = {
        home.packages = [ pkgs.nh ];

        home.shellAliases =
          let
            nh = lib.getExe pkgs.nh;
            flake = "${config.home.homeDirectory}/dotfiles";
          in
          {
            noss = "${nh} os switch ${flake}";
            nost = "${nh} os test ${flake}";
            nosb = "${nh} os boot ${flake}";
            ndws = "${nh} darwin switch ${flake}";
            nhms = "${nh} home switch ${flake}";
            nca = "${nh} clean all --no-gcroots";
          };
      };
    };
}
