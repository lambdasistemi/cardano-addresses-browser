default:
  @just --list

install:
  npm install
  npx spago install -p cardano-addresses
  npx spago install -p cardano-addresses-browser

build:
  npx spago build -p cardano-addresses
  npx spago build -p cardano-addresses-browser

bundle:
  just build
  npx esbuild output/Main/index.js --bundle --outfile=dist/app.js --format=esm --minify

bundle-lib:
  npx spago build -p cardano-addresses
  npx esbuild output/Cardano.Address/index.js --bundle --outfile=dist/cardano-addresses.js --format=esm --minify

dev:
  just build
  npx esbuild output/Main/index.js --bundle --outfile=dist/app.js --format=esm --serve=0.0.0.0:8080 --servedir=dist

format:
  npx purs-tidy format-in-place "lib/src/**/*.purs" "app/src/**/*.purs"

check:
  npx purs-tidy check "lib/src/**/*.purs" "app/src/**/*.purs"

ci: build check
