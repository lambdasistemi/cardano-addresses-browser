default:
  @just --list

install:
  npm install
  npx spago install -p cardano-addresses
  npx spago install -p cardano-addresses-browser

build:
  npx spago build -p cardano-addresses
  npx spago build -p cardano-addresses-browser

test:
  npx spago test -p cardano-addresses-test

vectors:
  rm -rf result
  nix build .#test-vectors
  mkdir -p test-vectors
  cp result/vectors.json test-vectors/vectors.json

check-vectors:
  rm -rf result
  nix build .#test-vectors
  diff -u test-vectors/vectors.json result/vectors.json

bundle:
  just build
  npx esbuild output/Main/index.js --bundle --outfile=dist/app.js --format=esm --minify --alias:fs=./app/shims/fs.cjs --alias:path=./app/shims/path.cjs

bundle-lib:
  npx spago build -p cardano-addresses
  npx esbuild output/Cardano.Address/index.js --bundle --outfile=dist/cardano-addresses.js --format=esm --minify

dev:
  just build
  npx esbuild output/Main/index.js --bundle --outfile=dist/app.js --format=esm --serve=0.0.0.0:8080 --servedir=dist --alias:fs=./app/shims/fs.cjs --alias:path=./app/shims/path.cjs

format:
  npx purs-tidy format-in-place "lib/src/**/*.purs" "app/src/**/*.purs"

check:
  npx purs-tidy check "lib/src/**/*.purs" "app/src/**/*.purs"

ci: check build check-vectors test
