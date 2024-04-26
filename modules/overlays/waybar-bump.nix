final: prev: {
  waybar = prev.waybar.overrideAttrs (old:
    rec {
      version = "0.10.2";
      src = prev.fetchFromGitHub {
        inherit (old.src) owner repo;
        rev = version;
        hash = "sha256-xinTLjZJhL4048jpAbN3i6nSxKAqnbesbK/GBX+1CkE=";
      };
    }
  );
}
  
