{
  description = "cardano-address-browser — Browser-based Cardano address toolkit";
  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys =
      [ "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ=" ];
  };

  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, haskellNix, purescript-overlay, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              haskellNix.overlay
              purescript-overlay.overlays.default
            ];
          };
          indexState = "2026-04-05T22:14:51Z";
          haskellProject = import ./nix/project.nix {
            inherit indexState pkgs;
          };
          playwrightBrowsers = pkgs.playwright-driver.browsers;
          test-vectors-json = pkgs.runCommand "cardano-addresses-browser-test-vectors" {} ''
            mkdir -p $out
            ${haskellProject.packages.test-vectors-exe}/bin/cardano-addresses-browser-vectors > $out/vectors.json
          '';
          testVectorsPath = test-vectors-json;
          apps = import ./nix/apps {
            inherit pkgs playwrightBrowsers testVectorsPath;
            repoRoot = ./.;
          };
        in
        {
          packages.playwright-browsers = playwrightBrowsers;
          packages.test-vectors-exe = haskellProject.packages.test-vectors-exe;
          packages.test-vectors = test-vectors-json;
          inherit apps;
          devShells.default = pkgs.mkShell {
            inputsFrom = [ haskellProject.devShells.default ];
            packages = [
              pkgs.cabal-install
              pkgs.fourmolu
              pkgs.hlint
              pkgs.purs
              pkgs.spago
              pkgs.purs-tidy
              pkgs.purs-backend-es
              pkgs.purescript-language-server
              pkgs.esbuild
              pkgs.nodejs_22
              pkgs.just
            ];
          };
        };
    };
}
