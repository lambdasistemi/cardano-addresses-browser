# Build cardano-addresses Haskell library to WASM using GHC's WASM backend.
#
# Uses the Fixed-Output Derivation (FOD) pattern:
#   1. `deps` fetches all Hackage dependencies (network access allowed in FOD)
#   2. `wasm` builds the project offline using the fetched deps
#
# The `dependenciesHash` must be updated when cabal-wasm.project or
# cardano-addresses.cabal changes. Set it to "" to get the expected hash
# from the build failure.
{ pkgs
, ghcWasmToolchain  # ghc-wasm-meta#all_9_12
, cardanoAddressesSrc  # source of paolino/cardano-addresses
, dependenciesHash ? ""
}:

let
  projectFile = "cabal-wasm.project";

  # Pre-fetch source-repository-package git deps for offline build
  cborg-src = pkgs.fetchgit {
    url = "https://github.com/well-typed/cborg.git";
    rev = "72a0e736e24c864b5a9b95d90adb37a9e8e6d761";
    hash = "sha256-SDzMk6gWXelE3OH6gCC6XSn+h5VbrKpaisyza9bCtVM=";
  };

  ram-src = pkgs.fetchgit {
    url = "https://github.com/paolino/ram.git";
    rev = "e6d863d240246e0a1af3dd12cff7047f696f81ea";
    hash = "sha256-hqBp5+Ti3bzGSR+JKRl7u7fbXb11L/kw2k0Pguq0xIM=";
  };

  # Only files that affect dependency resolution
  srcMetadata = pkgs.lib.cleanSourceWith {
    src = cardanoAddressesSrc;
    filter = name: type:
      let baseName = baseNameOf (toString name); in
      type == "directory" ||
      pkgs.lib.hasSuffix ".cabal" baseName ||
      baseName == projectFile;
  };

  # Phase 1: Fetch all Hackage dependencies (FOD with network access)
  deps = pkgs.stdenv.mkDerivation {
    pname = "cardano-addresses-wasm-deps";
    version = "0.1.0";

    src = srcMetadata;

    nativeBuildInputs = [ ghcWasmToolchain pkgs.cacert pkgs.git pkgs.curl ];

    buildPhase = ''
      export HOME=$NIX_BUILD_TOP/home
      mkdir -p $HOME
      export CABAL_DIR=$NIX_BUILD_TOP/cabal
      mkdir -p $CABAL_DIR
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      export CURL_CA_BUNDLE=$SSL_CERT_FILE

      # wasm32-wasi-cabal manages its own config; we just need to update + download
      wasm32-wasi-cabal update
      wasm32-wasi-cabal --project-file=${projectFile} build --only-download cardano-addresses-wasm
    '';

    installPhase = ''
      # Copy the entire cabal directory as our cached store
      mkdir -p $out
      cp -r $CABAL_DIR/* $out/
    '';

    outputHashMode = "recursive";
    outputHash = dependenciesHash;
  };

  # Phase 2: Build WASM offline using fetched deps
  wasm = pkgs.stdenv.mkDerivation {
    pname = "cardano-addresses-wasm";
    version = "0.1.0";

    src = cardanoAddressesSrc;

    nativeBuildInputs = [ ghcWasmToolchain pkgs.git ];

    configurePhase = ''
      export HOME=$NIX_BUILD_TOP/home
      mkdir -p $HOME
      export CABAL_DIR=$NIX_BUILD_TOP/cabal
      mkdir -p $CABAL_DIR

      # Point cabal at the pre-fetched dependency store
      cp -r ${deps}/* $CABAL_DIR/
      chmod -R u+w $CABAL_DIR

      # Replace source-repository-package entries with local paths
      # so the build doesn't need network access
      cp ${projectFile} ${projectFile}.orig
      sed -i '/^source-repository-package/,/^$/d' ${projectFile}
      cat >> ${projectFile} <<EOF

      packages:
        cardano-addresses.cabal
        ${cborg-src}/cborg/cborg.cabal
        ${ram-src}/ram.cabal
      EOF
    '';

    buildPhase = ''
      wasm32-wasi-cabal --project-file=${projectFile} build cardano-addresses-wasm
    '';

    installPhase = ''
      mkdir -p $out
      find dist-newstyle -name "cardano-addresses-wasm.wasm" -type f \
        -exec cp {} $out/cardano-addresses.wasm \;
    '';
  };

in {
  inherit deps wasm;
}
