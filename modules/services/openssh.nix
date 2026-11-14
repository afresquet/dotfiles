{
  flake.modules.darwin.openssh = _: {
    config = {
      services.openssh.enable = true;
    };
  };
}
