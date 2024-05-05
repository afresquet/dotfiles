final: prev: {
  obsidian = prev.symlinkJoin {
    name = "obsidian";
    paths = [ prev.obsidian ];
    buildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/obsidian \
        --add-flags "--enable-features=UseOzonePlatform" \
        --add-flags "--ozone-platform=wayland"
    '';
  };
}
