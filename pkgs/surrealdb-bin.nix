{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  glibc,
  gcc-unwrapped,
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "surrealdb-bin";
  version = "2.1.4";

  src = fetchzip {
    url = "https://github.com/surrealdb/surrealdb/releases/download/v${finalAttrs.version}/surreal-v${finalAttrs.version}.linux-amd64.tgz";
    hash = "sha256-pNsp8RF6CgjRgbpf6oYhseaUve3FTWJz6MAwuyWcEpk=";
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

  meta = {
    description = "SurrealDB server and CLI, prebuilt binary";
    homepage = "https://surrealdb.com";
    license = lib.licenses.bsl11;
    platforms = [ "x86_64-linux" ];
    mainProgram = "surreal";
  };
})
