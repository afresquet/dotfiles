{ self, ... }:
{
  flake.modules.nixos."1password" =
    { config, ... }:
    {
      imports = [
        self.modules.nixos.primary-user
        self.modules.nixos.allowed-unfree
      ];

      config = {
        programs._1password.enable = true;
        programs._1password-gui = {
          enable = true;
          polkitPolicyOwners = [ config.system.primaryUser ];
        };

        allowedUnfree = [
          "1password"
          "1password-cli"
          "1password-gui"
        ];
      };
    };
}
