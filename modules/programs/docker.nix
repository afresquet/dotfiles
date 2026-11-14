{ self, ... }:
{
  flake.modules.nixos.docker =
    { config, ... }:
    {
      imports = [ self.modules.nixos.primary-user ];

      config = {
        virtualisation.docker.enable = true;

        users.extraGroups.docker.members = [ config.system.primaryUser ];
      };
    };
}
