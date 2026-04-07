{pkgs, playwrightBrowsers, repoRoot, testVectorsPath}:

let
  lib = import ./lib.nix { inherit pkgs playwrightBrowsers repoRoot; };
in
{
  "ci-install" = import ./install.nix { inherit lib; };
  "ci-check" = import ./check.nix { inherit lib; };
  "ci-build" = import ./build.nix { inherit lib; };
  "ci-haskell-quality" = import ./haskell-quality.nix { inherit lib; };
  "ci-check-vectors" = import ./check-vectors.nix { inherit lib testVectorsPath; };
  "ci-test" = import ./test.nix { inherit lib; };
  "ci-playwright" = import ./playwright.nix { inherit lib; };
}
