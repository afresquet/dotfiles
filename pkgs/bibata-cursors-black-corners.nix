{
  bibata-cursors,
  librsvg,
  ...
}:
bibata-cursors.overrideAttrs (old: {
  pname = "bibata-cursors-black-corners";

  nativeBuildInputs = old.nativeBuildInputs ++ [ librsvg ];

  buildPhase = ''
    runHook preBuild

    cp -r --no-preserve=mode ${old.bitmaps}/Bibata-Modern-Classic bitmaps

    for corner in top_left top_right bottom_left bottom_right; do
      sed -E \
        -e 's/#(00FF00|FF0000|4FADDF|F1613A|96C865|FDBE2A)/#000000/gI' \
        -e 's/#0000FF/#FFFFFF/gI' \
        svg/modern/''${corner}_corner.svg \
        | rsvg-convert -w 256 -h 256 -o bitmaps/''${corner}_corner.png
    done

    ctgen configs/normal/x.build.toml -p x11 -d bitmaps -n 'Bibata-Modern-Classic-Black-Corners' -c 'Black and rounded edge Bibata XCursors with black resize corners'

    runHook postBuild
  '';
})
