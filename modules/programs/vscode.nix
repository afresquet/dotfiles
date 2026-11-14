{ self, ... }:
{
  flake.modules.nixos.vscode =
    {
      pkgs,
      ...
    }:
    {
      imports = [ self.modules.nixos.allowed-unfree ];

      config = {
        environment.systemPackages = with pkgs; [
          vscode
        ];

        allowedUnfree = [ "vscode" ];
      };
    };
}
