# OWASP CRS for ModSecurity. nixpkgs ships 3.3.4, which predates the 2026-07 security fixes.
{
  fetchFromGitHub,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "coreruleset";
  version = "4.25.1";

  src = fetchFromGitHub {
    owner = "coreruleset";
    repo = "coreruleset";
    rev = "v${finalAttrs.version}";
    hash = "sha256-dSzy1rJgPxc7qAivevR+a8BpGRi0CjrG0q+U3kXr48Q=";
  };

  installPhase = ''
    cp -r . "$out"
  '';
})
