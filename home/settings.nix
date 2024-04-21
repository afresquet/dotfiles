{ lib, args, ... }: {
  options = {
    username = lib.mkOption {
      default = args.username;
      type = lib.types.str;
      description = "Home Manager Username";
    };
  };
}
