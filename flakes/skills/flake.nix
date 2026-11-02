{
  description = "Upstream sources for AI agent skills";

  inputs = {
    grepika = {
      url = "github:adamthewilliam/grepika";
      flake = false;
    };
    tilth = {
      url = "github:jahala/tilth";
      flake = false;
    };
  };

  outputs = inputs: {
    inherit (inputs) grepika tilth;
  };
}
