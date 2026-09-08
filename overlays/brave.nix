final: prev: {
  brave = prev.symlinkJoin {
    name = "brave";
    paths = [ prev.brave ];
    buildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/brave \
        --add-flags "--enable-features=TouchpadOverscrollHistoryNavigation"
    '';
    meta = prev.brave.meta // {
      mainProgram = "brave";
    };
  };
}
