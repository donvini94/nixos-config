# The browser assets n8n's hosted chat page loads from jsDelivr, served from the
# customer's own domain instead (privacy, and no unpinned third-party script).
{
  fetchurl,
  stdenvNoCC,
}:

let
  normalize = fetchurl {
    url = "https://registry.npmjs.org/normalize.css/-/normalize.css-8.0.1.tgz";
    hash = "sha256-XMFy4NXQYrwqGkv4VEPi6yYNNyDhZSegwawDtkLx3jk=";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "n8n-chat";
  version = "1.40.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@n8n/chat/-/chat-${finalAttrs.version}.tgz";
    hash = "sha256-5MQocxr0rz3ajPrxPKeN7f1IplPyJIeMvjAH0narQL8=";
  };

  installPhase = ''
    # Laid out like jsDelivr's /npm/ tree, so one URL prefix rewrite covers both files.
    install -Dm644 -t "$out/@n8n/chat/dist" dist/chat.bundle.es.js dist/style.css
    # The page asks for the minified file; the package ships only the readable one.
    tar -xzf ${normalize} package/normalize.css
    install -Dm644 package/normalize.css "$out/normalize.css@8.0.1/normalize.min.css"
  '';
})
