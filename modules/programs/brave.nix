{
  flake.modules.darwin.brave = _: {
    config = {
      homebrew.casks = [ "brave-browser" ];
    };
  };
}
