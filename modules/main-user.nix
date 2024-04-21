{ lib, config, pkgs, ... }: {
  options = {
    username = lib.mkOption {
      default = "afresquet";
      type = lib.types.str;
      description = "Main User Username";
    };

    description = lib.mkOption {
      default = "Alvaro";
      type = lib.types.str;
      description = "Main User Description";
    };

    shell = lib.mkOption {
      default = pkgs.nushell;
      type = lib.types.package;
      description = "Main User Shell";
    };
  };

  config =
    let
      inherit (config) username description shell;
    in
    {
      # Define a user account. Don't forget to set a password with ‘passwd’.
      users.users.${username} = {
        homeMode = "755";
        isNormalUser = true;
        extraGroups = [ "networkmanager" "wheel" ];
        packages = [ ];
        inherit description shell;
      };
    };
}
