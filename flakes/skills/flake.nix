{
  description = "Upstream sources for AI agent skills";

  inputs = {
    tilth = {
      url = "github:jahala/tilth";
      flake = false;
    };
  };

  outputs = inputs: {
    inherit (inputs) tilth;
  };
}
