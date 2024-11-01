{
  stdenv,
  fetchzip,
  autoPatchelfHook,
  glibc,
  gcc-unwrapped,
}:
stdenv.mkDerivation rec {
  name = "surrealdb-bin";
  pname = "surreal";
  version = "2.0.4";

  src = fetchzip {
    url = "https://github.com/surrealdb/surrealdb/releases/download/v${version}/surreal-v${version}.linux-amd64.tgz";
    sha256 = "sha256-BQxjx45nBLnjOBHe0Ata/t/QcMCHdXzy/ci0RhY70SQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    glibc
    gcc-unwrapped
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m755 surreal $out/bin
    runHook postInstall
  '';
}
