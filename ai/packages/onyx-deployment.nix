# Onyx's upstream Docker Compose deployment: the compose file and the nginx templates it
# mounts by relative path. The module overrides images, ports and services on top.
{
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "onyx-deployment";
  version = "4.8.4";

  src = fetchFromGitHub {
    owner = "onyx-dot-app";
    repo = "onyx";
    rev = "v${finalAttrs.version}";
    sparseCheckout = [
      "deployment/docker_compose"
      "deployment/data/nginx"
    ];
    hash = "sha256-aY78XQ6OjtO+yacXOUqZY5wL97fWjzSGvjSSgj6tWKY=";
  };

  dontBuild = true;
  # The scripts run inside upstream's containers; their shebangs must stay as shipped.
  dontFixup = true;
  installPhase = ''
    cp -r deployment "$out"
  '';
})
