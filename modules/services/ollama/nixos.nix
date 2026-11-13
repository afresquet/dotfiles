{ lib, config, ... }:
let
  cfg = config.ollama;
in
{
  options = {
    ollama.enable = lib.mkEnableOption "Ollama" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable the Ollama daemon.
    services.ollama.enable = true;
  };
}
