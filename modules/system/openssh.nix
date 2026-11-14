{
  flake.modules.darwin.openssh = _: {
    services.openssh.enable = true;
  };
}
