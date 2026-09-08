# Apache Tika server, ahead of nixpkgs.
#
# UPSTREAM DEFECT: nixpkgs is on 2.9.3, and CVE-2025-66516 is an XXE in tika-core
# 1.13 through 3.2.1 with no 2.x backport, so the fix is only reachable by moving to
# the 3.x line. Drop this file once nixpkgs ships tika >= 3.2.2.
#
# 3.3.2 rather than 4.0.0: upstream stopped publishing runnable jars in 4.x, where
# the Maven artifact fails standalone with NoClassDefFoundError. 3.x remains
# supported, and paperless-ngx itself tests against 3.3.x.
{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  jdk17_headless,
  tesseract,
  enableOcr ? false,
  # Accepted because nixos/modules/services/search/tika.nix overrides both; a
  # prebuilt server jar has no GUI to build out.
  enableGui ? false,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tika";
  version = "3.3.2";

  src = fetchurl {
    url = "https://repo1.maven.org/maven2/org/apache/tika/tika-server-standard/${finalAttrs.version}/tika-server-standard-${finalAttrs.version}.jar";
    hash = "sha512-+x8v5XrEWLCdRNQdgW9YLh0vyTSIrP9idcr0FNjV75TkIWbtwLSI3C+27zqiH6tisQfEO5BgOF/21nXjk8LJ6Q==";
  };

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm444 "$src" "$out/share/tika/tika-server.jar"
    # jdk on PATH, not just as the exec target: TikaServerWatchDog forks the actual
    # parser process with ProcessBuilder("java"), so a bare absolute exec starts and
    # then dies with "Cannot run program java".
    makeWrapper ${lib.getExe' jdk17_headless "java"} "$out/bin/tika-server" \
      --add-flags "-jar $out/share/tika/tika-server.jar" \
      --prefix PATH : ${
        lib.makeBinPath ([ jdk17_headless ] ++ lib.optional enableOcr tesseract)
      }
    runHook postInstall
  '';

  meta = {
    description = "Toolkit for extracting metadata and text from over a thousand different file types";
    homepage = "https://tika.apache.org";
    license = lib.licenses.asl20;
    mainProgram = "tika-server";
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
  };
})
