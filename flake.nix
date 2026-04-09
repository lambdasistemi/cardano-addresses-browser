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
    mkSpagoDerivation = {
      url = "github:jeslie0/mkSpagoDerivation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghc-wasm-meta = {
      url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
      flake = true;
    };
    cardano-addresses-src = {
      url = "github:paolino/cardano-addresses/001-wasm-target";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, haskellNix, mkSpagoDerivation, purescript-overlay, ghc-wasm-meta, cardano-addresses-src, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { system, ... }:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              haskellNix.overlay
              mkSpagoDerivation.overlays.default
              purescript-overlay.overlays.default
            ];
          };
          indexState = "2026-04-05T22:14:51Z";
          repoRoot = ./.;
          haskellProject = import ./nix/project.nix {
            inherit indexState pkgs;
          };
          wasmBuild = import ./nix/wasm.nix {
            inherit pkgs;
            ghcWasmToolchain = ghc-wasm-meta.packages.${system}.all_9_12;
            cardanoAddressesSrc = cardano-addresses-src;
            dependenciesHash = "sha256-1+NZ8RA5wCmiHsefwkqfGedNErgA8gM4cCG3V7q4Cik=";
          };
          playwrightBrowsers = pkgs.playwright-driver.browsers;
          test-vectors-json = pkgs.runCommand "cardano-addresses-browser-test-vectors" {} ''
            mkdir -p $out
            ${haskellProject.packages.test-vectors-exe}/bin/cardano-addresses-browser-vectors > $out/vectors.json
          '';
          testVectorsPath = test-vectors-json;
          purescript = import ./nix/purescript.nix {
            inherit pkgs repoRoot;
          };
          packages = import ./nix/packages {
            inherit pkgs repoRoot purescript haskellProject playwrightBrowsers testVectorsPath;
          };
          checks = import ./nix/checks {
            inherit pkgs repoRoot purescript packages playwrightBrowsers testVectorsPath wasmBuild;
          };
          apps = import ./nix/apps {
            inherit pkgs checks system;
          };
        in
        {
          packages.playwright-browsers = playwrightBrowsers;
          packages.test-vectors-exe = haskellProject.packages.test-vectors-exe;
          packages.test-vectors = test-vectors-json;
          packages.wasm = wasmBuild.wasm;
          packages.wasm-deps = wasmBuild.deps;
          packages.web-dist = packages.web-dist;
          checks = checks;
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
