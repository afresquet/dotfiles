{ lib, config, ... }: {
  options = {
    packages = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.package;
      description = "User Packages";
    };
  };

  config = {
    users.users.${config.username}.packages = config.packages;
  };
}
