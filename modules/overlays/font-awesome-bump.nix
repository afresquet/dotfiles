final: prev: {
  font-awesome = prev.font-awesome.overrideAttrs (old:
    rec {
      version = "6.5.2";
      src = prev.fetchFromGitHub {
        inherit (old.src) owner repo;
        rev = version;
        hash = "sha256-kUa/L/Krxb5v8SmtACCSC6CI3qTTOTr4Ss/FMRBlKuw=";
      };
    }
  );
}
  
