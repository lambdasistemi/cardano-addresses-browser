default:
  @just --list

install:
  npm install
  spago install

build:
  spago build

bundle:
  spago build
  esbuild output/Main/index.js --bundle --outfile=dist/app.js --format=esm --minify

bundle-lib:
  spago build -p cardano-addresses
  esbuild output/Cardano.Address/index.js --bundle --outfile=dist/cardano-addresses.js --format=esm --minify

dev:
  spago build
  esbuild output/Main/index.js --bundle --outfile=dist/app.js --format=esm --serve=0.0.0.0:8080 --servedir=dist

format:
  purs-tidy format-in-place "lib/src/**/*.purs" "app/src/**/*.purs"

check:
  purs-tidy check "lib/src/**/*.purs" "app/src/**/*.purs"

ci: build check
