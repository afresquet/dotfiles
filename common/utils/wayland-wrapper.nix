{ name, package ? name, bin ? name, pkgs }:
pkgs.symlinkJoin {
  inherit name;
  paths = [ pkgs.${package} ];
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/${bin} \
      --add-flags "--enable-features=UseOzonePlatform" \
      --add-flags "--ozone-platform=wayland"
  '';
}
