final: prev: {
  brave =
    prev.symlinkJoin {
      name = "brave";
      paths = [ prev.brave ];
      buildInputs = [ prev.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/brave \
          --add-flags "--enable-features=UseOzonePlatform" \
          --add-flags "--ozone-platform=wayland" \
          --add-flags "--ozone-platform-hint=auto" \
          --add-flags "--enable-features=TouchpadOverscrollHistoryNavigation"
      '';
    };
}
