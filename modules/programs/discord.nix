{ lib, config, pkgs, ... }: {
  options = {
    discord.enable = lib.mkEnableOption "Discord";
  };

  config = {
    packages = lib.mkIf config.discord.enable [
      (pkgs.symlinkJoin {
        name = "discord";
        paths = [ pkgs.discord ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/discord \
            --add-flags "--enable-features=UseOzonePlatform" \
            --add-flags "--ozone-platform=wayland"
        '';
      })
    ];

    allowedUnfree = [
      "discord"
    ];
  };
}
