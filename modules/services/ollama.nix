{
  flake.modules.nixos.ollama = _: {
    config = {
      # Enable the Ollama daemon.
      services.ollama.enable = true;
    };
  };
}
