# Cardano Addresses Web Constitution

## Core Principles

### I. Browser-Native
All functionality runs entirely in the browser. No server, no backend. The app must work offline after initial load (WASM binary cached via HTTP).

### II. Haskell as Source of Truth
Cryptographic operations MUST use the real Haskell `cardano-addresses` library compiled to WASM. No JS reimplementation of crypto primitives. The Haskell library is the authority for correctness — not golden tests, not JS code. JS is used only for encoding utilities (bech32, base58, hex) and browser APIs (random number generation).

### III. Feature Parity with CLI
Every command from the `cardano-addresses` CLI must have a corresponding UI panel. The same inputs produce the same outputs, guaranteed by running the same code.

### IV. Pipeline UX
Operations chain naturally: mnemonic → root key → account key → address key → address. The UI makes this pipeline visible and interactive — output of one step feeds into the next.

### V. PureScript + Halogen
Frontend built with PureScript and Halogen. WASM and encoding libraries accessed via FFI. Build with Spago, bundle with esbuild. Nix flake for reproducible dev environment.

### VI. Correctness Over Features
Every new feature must be backed by the Haskell library via WASM if it involves cryptography or address manipulation. Adding JS crypto code requires explicit justification.

## Technical Constraints

- PureScript 0.15.x, Spago workspace format
- Halogen 7 for UI components
- Single `cardano-addresses.wasm` binary via `@bjorn3/browser_wasi_shim`
- FFI to: `@noble/hashes` (blake2b for script hashing), `bech32` (encoding), `@scure/base` (base58), `@scure/bip39` (mnemonic generation)
- No runtime dependencies beyond bundled JS and WASM
- Single-page app, no routing library needed — sidebar tab switching only

## Quality Gates

- `spago build` clean with no warnings
- `purs-tidy check` passes
- Bundle size under 500KB gzipped (excluding WASM binary)
- WASM binary loaded on demand, not blocking page render
- Works in Chrome, Firefox, Safari latest

## Governance

Constitution governs all development decisions. Amendments require documentation.

**Version**: 2.0.0 | **Ratified**: 2026-04-05 | **Last Amended**: 2026-04-09
