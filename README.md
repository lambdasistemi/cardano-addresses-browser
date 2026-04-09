# cardano-addresses-browser

Browser-based Cardano address toolkit. Mnemonic generation, key derivation, address construction, inspection, signing — all running client-side with no backend.

## Architecture

The core cryptographic operations are performed by the real Haskell [cardano-addresses](https://github.com/IntersectMBO/cardano-addresses) library, compiled to WebAssembly. This guarantees byte-identical behavior with the upstream implementation — there is no reimplementation to drift or audit.

### What comes from Haskell (via WASM)

A single `cardano-addresses.wasm` binary (~7MB) provides all cryptographic and address logic through a JSON command dispatch protocol over WASI stdin/stdout:

| Command | What it does |
|---------|-------------|
| `inspect` | Decode any Cardano address (Shelley, Byron, Icarus) into its components |
| `derive` | BIP32-Ed25519 key derivation from mnemonic (CIP-1852 Shelley scheme) |
| `make-address` | Construct Shelley addresses (enterprise, base, reward) from public keys |
| `sign` | Ed25519 message signing with extended private keys |
| `verify` | Ed25519 signature verification with extended public keys |
| `bootstrap-address` | Legacy Byron and Icarus address construction from mnemonics or public keys |

The WASM binary is built from [paolino/cardano-addresses](https://github.com/paolino/cardano-addresses/tree/001-wasm-target) using GHC's WASM backend (`wasm32-wasi-ghc` 9.12). It runs in the browser via [@bjorn3/browser_wasi_shim](https://github.com/aspect-build/aspect-workflows/tree/main/packages/browser_wasi_shim) which fakes WASI syscalls (stdin/stdout/stderr) in JavaScript.

Measured overhead: ~9ms one-time module compile, ~3ms per call (Shelley), ~13ms for legacy CBOR-heavy operations.

### What stays in JavaScript

These operations do not involve cryptographic reimplementation and remain in JS:

| Module | Dependency | Purpose |
|--------|-----------|---------|
| `Mnemonic.js` | `@scure/bip39` | Mnemonic generation (needs browser `crypto.getRandomValues`) and word validation |
| `Hash.js` | `@noble/hashes` | Blake2b-224 credential hashing (3 lines; used by `Shelley.purs` address construction) |
| `Shelley.js` | none | Shelley address byte assembly (11 lines; pure concatenation, no crypto) |
| `Script.js` | `bech32`, `@noble/hashes` | Native script CBOR parsing, JSON canonicalization, validation, and script hash computation |
| `Bech32.js` | `bech32` | Bech32 encoding/decoding for UI display |
| `Base58.js` | `@scure/base` | Base58 encoding/decoding for legacy address display |
| `Hex.js` | none | Hex encoding/decoding |
| `Bytes.js` | none | Byte array utilities |

These are standardized encoding libraries with their own test suites — not custom crypto code.

### What was removed

The `cardano-crypto.js` dependency (BIP32-Ed25519, PBKDF2, ChaCha20-Poly1305, HD passphrase derivation) and ~400 lines of hand-written JS (CBOR parser, address inspector) have been replaced by the WASM binary.

## Stack

- **UI**: PureScript 0.15 + Halogen 7
- **Crypto**: Haskell cardano-addresses compiled to WASM
- **Build**: Spago (PureScript), esbuild (bundler), Nix flake (reproducible environment)
- **Tests**: PureScript unit tests against Haskell-generated golden vectors, Playwright E2E

## Project structure

```
app/                    Halogen application (UI shell)
lib/                    PureScript library (address types, FFI bindings)
  src/Cardano/Address/
    Wasm.js             WASM bridge (browser_wasi_shim integration)
    Inspect.js          → WASM inspect command
    Derivation.js       → WASM derive command
    Signing.js          → WASM sign/verify commands
    Bootstrap.js        → WASM bootstrap-address command
    Shelley.js          Address byte assembly (pure JS)
    Hash.js             Blake2b-224 (@noble/hashes)
    Script.js           Native script analysis (CBOR + bech32)
    Bech32.js           Bech32 encoding (bech32 lib)
    Base58.js           Base58 encoding (@scure/base)
dist/
  index.html            Single-page app entry point
  wasm/                 WASM binary (gitignored, fetched from CI)
haskell/                Test vector generator (upstream cardano-addresses)
test/                   PureScript golden vector tests
tests/                  Playwright E2E tests
specs/                  Spec-driven development artifacts
```

## Development

```bash
nix develop              # Enter dev shell
npm install              # Install JS dependencies
just build               # Build PureScript
just bundle              # Bundle for browser
just dev                 # Dev server with live rebuild
just test                # Run golden vector tests
just ci                  # Full CI (format, build, test, playwright)
```

## WASM binary

The WASM binary is not committed to this repo. It is built from [paolino/cardano-addresses](https://github.com/paolino/cardano-addresses/tree/001-wasm-target) and placed in `dist/wasm/`:

```bash
# In the cardano-addresses repo:
wasm32-wasi-cabal --project-file=cabal-wasm.project build cardano-addresses-wasm

# Copy to this repo:
cp dist-newstyle/build/wasm32-wasi/.../cardano-addresses-wasm.wasm \
   ../cardano-addresses-browser/dist/wasm/cardano-addresses.wasm
```

## Testing

Golden test vectors are generated by the Haskell executable in `haskell/` using the upstream `cardano-addresses` library. The PureScript tests verify that the browser implementation (now backed by the same Haskell library via WASM) matches these vectors.

For operations served by WASM, the golden tests are redundant by construction — they test the same code that generated them. They remain as regression tests for the JS-side encoding and UI integration.
