{ self, ... }:
{
  flake.modules.nixos."1password" =
    { config, ... }:
    {
      imports = [
        self.modules.nixos.primary-user
        self.modules.nixos.allowed-unfree
      ];

      programs._1password.enable = true;
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.system.primaryUser ];
      };

      # 1Password's browser support only talks to browsers it recognises by
      # executable name, and Zen isn't on its built-in list.
      environment.etc."1password/custom_allowed_browsers" = {
        text = ''
          zen
        '';
        mode = "0755";
      };

      allowedUnfree = [
        "1password"
        "1password-cli"
        "1password-gui"
      ];
    };
}
