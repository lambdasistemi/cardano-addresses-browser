# Cardano Addresses Web Constitution

## Core Principles

### I. Browser-Native
All functionality runs entirely in the browser. No server, no backend. Crypto operations use JS libraries via FFI. The app must work offline after initial load.

### II. Feature Parity with CLI
Every command from the `cardano-addresses` CLI must have a corresponding UI panel. The same inputs produce the same outputs. Bech32/Base58 encodings are byte-identical to the Haskell implementation.

### III. Pipeline UX
Operations chain naturally: mnemonic → root key → account key → address key → address. The UI makes this pipeline visible and interactive — output of one step feeds into the next.

### IV. PureScript + Halogen
Frontend built with PureScript and Halogen. JS crypto libraries accessed via FFI. Build with Spago, bundle with esbuild. Nix flake for reproducible dev environment using purescript-overlay.

### V. Correctness Over Features
Every encoding/hashing function must produce output identical to the Haskell reference implementation. Test against known test vectors from the cardano-addresses test suite.

### VI. Reference Semantics Over Implementation Loyalty
Haskell `cardano-addresses` is the authority for behavior. Haskell-generated vectors define the compatibility contract. JavaScript dependencies such as `cardano-crypto.js` are implementation tools only: use them where they directly and faithfully map to upstream semantics, but do not force uniform use of a dependency across the whole codebase just for consistency. If a simpler implementation matches the Haskell vectors, prefer the simpler implementation.

## Technical Constraints

- PureScript 0.15.x, Spago workspace format
- Halogen 7 for UI components
- FFI to: @noble/hashes (blake2b), bech32 (bech32 encoding), @scure/base (base58), @scure/bip39 (mnemonics)
- Ed25519 BIP32 key derivation via cardano-crypto.js (or emip3 if needed)
- No runtime dependencies beyond bundled JS
- Single-page app, no routing library needed — sidebar tab switching only

## Quality Gates

- `spago build` clean with no warnings
- `purs-tidy check` passes
- Bundle size under 500KB gzipped
- Works in Chrome, Firefox, Safari latest

## Governance

Constitution governs all development decisions. Amendments require documentation.

**Version**: 1.0.0 | **Ratified**: 2026-04-05
