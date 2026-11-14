{ self, ... }:
{
  flake.modules.nixos.slicers =
    {
      pkgs,
      ...
    }:
    {
      imports = [ self.modules.nixos.allowed-unfree ];

      config = {
        xdg.mime.defaultApplications = {
          "x-scheme-handler/bambustudio" = "BambuStudio.desktop";
        };

        environment.systemPackages = with pkgs; [
          bambu-studio
          cura
          orca-slicer
          prusa-slicer
          openscad-unstable
        ];

        allowedUnfree = [ "bambu-studio" ];
      };
    };
}
