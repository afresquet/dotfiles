{ inputs, ... }:
{
  flake.modules.homeManager.zen-browser =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      key = "self.modules.homeManager.zen-browser";
      imports = [ inputs.zen-browser.homeModules.beta ];

      config = {
        programs.zen-browser = {
          enable = true;
          profiles.default = { };
        };

        stylix.targets.zen-browser.profileNames = [ "default" ];

        home.activation.defaultBrowser = lib.hm.dag.entryAfter [ "installPackages" "linkGeneration" ] ''
          run env -u BROWSER \
            PATH=${config.home.profileDirectory}/bin:$PATH \
            XDG_DATA_DIRS=${config.home.profileDirectory}/share \
            ${pkgs.xdg-utils}/bin/xdg-settings set default-web-browser zen-beta.desktop
        '';
      };
    };
}
