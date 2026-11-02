# fzf 0.74.5's nushell completer declares the positional `spans` input that
# nushell deprecated. Upstream master has migrated to `place` but no release
# includes it yet, so this throws on any fzf bump as a reminder to check and
# drop the patch.
final: prev: {
  fzf =
    if prev.fzf.version == "0.74.5" then
      prev.fzf.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          substituteInPlace $out/share/fzf/completion.nu \
            --replace-fail 'let fzf_wrapper_completer = {|spans|' \
              'let fzf_wrapper_completer = {|place|
              let spans = $place.command'
        '';
      })
    else
      throw "fzf overlay: nixpkgs now ships ${prev.fzf.version}; check it includes the nushell `place` completer and remove overlays/fzf-nushell-completer.nix";
}
