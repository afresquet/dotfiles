final: prev: {
  discord = prev.symlinkJoin {
    name = "discord";
    paths = [ prev.discord ];
    buildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/discord \
        --add-flags "--enable-features=UseOzonePlatform" \
        --add-flags "--ozone-platform=wayland"
    '';
  };
}
