# Research: Replace JS Crypto with WASM

## Decision 1: WASM Architecture — Option A (Multiple WASI stdin/stdout executables)

**Decision**: Build separate WASM executables per operation, communicating via JSON on stdin/stdout.

**Rationale**: 
- `inspect-address.wasm` already works end-to-end in browser (proven in paolino/cardano-addresses PR #5)
- Each executable is testable independently with `wasmtime` on CLI
- No complex FFI boundary design or memory management
- WASI stdin/stdout is a stable, well-supported interface
- Cold start (~50ms) is acceptable for interactive use; module caching amortizes it

**Alternatives considered**:
- Option B (single WASM with command dispatch): marginally simpler deployment but more complex Haskell code. Can migrate later if needed.
- Option C (WASM reactor with exported functions): lowest latency but requires experimental GHC reactor mode. Too risky for now.

## Decision 2: WASM Loading Strategy

**Decision**: Fetch `.wasm` binaries on first use, cache via browser HTTP cache. Pre-instantiate WebAssembly.Module on page load.

**Rationale**:
- The existing demo (`browser/index.html`) already uses this pattern with `fetch()` + `WebAssembly.compile()`
- Compiled `WebAssembly.Module` can be reused across invocations — only the WASI FDs need to be recreated per call
- No service worker needed; standard HTTP caching headers suffice
- WASM binaries (~5MB each uncompressed, ~1.5MB gzipped) are acceptable for a developer tool

**Alternatives considered**:
- Bundling WASM as base64 in JS: bloats the JS bundle, defeats streaming compilation
- Service worker cache: over-engineering for a developer tool

## Decision 3: PureScript FFI Bridge Pattern

**Decision**: Single PureScript module `Cardano.Address.Wasm` that wraps browser_wasi_shim. Each operation gets a typed wrapper function.

**Rationale**:
- The existing FFI pattern uses `(onLeft) => (onRight) => input => result` callbacks
- The WASM bridge can follow the same pattern: serialize input to JSON, call WASM via shim, parse JSON output, call onLeft/onRight
- PureScript types (Inspect result, Key bytes, Address) remain unchanged — only the JS implementation changes
- One bridge module avoids duplicating WASI setup code

**Pattern**:
```javascript
// Wasm.js
export const callWasmImpl = (onLeft) => (onRight) => (wasmModule) => (inputJson) => () => {
  const encoder = new TextEncoder();
  const stdinData = encoder.encode(inputJson);
  let stdoutBuf = '';
  const fds = [
    new OpenFile(new File(stdinData)),
    ConsoleStdout.lineBuffered(line => { stdoutBuf += line + '\n'; }),
    ConsoleStdout.lineBuffered(() => {})
  ];
  const wasi = new WASI([], [], fds, { debug: false });
  const instance = await WebAssembly.instantiate(wasmModule, {
    wasi_snapshot_preview1: wasi.wasiImport
  });
  try {
    wasi.start(instance);
    return onRight(stdoutBuf.trim());
  } catch (e) {
    return onLeft(e.message || 'WASM execution failed');
  }
};
```

## Decision 4: WASM Binary Source

**Decision**: Build WASM binaries in CI from `paolino/cardano-addresses` using `wasm32-wasi-cabal`. Publish as GitHub release artifacts. Reference from the browser app via versioned URL.

**Rationale**:
- The WASM CI workflow already exists in `.github/workflows/wasm.yml` on the `001-wasm-target` branch of paolino/cardano-addresses
- WASM binaries are too large to commit to the browser repo
- Release artifacts provide versioning and reproducibility
- The Nix flake can fetch them as fixed-output derivations

**Alternatives considered**:
- Building WASM in the browser repo's CI: duplicates the WASM toolchain setup, slower CI
- Committing WASM to git: 5MB+ binaries in git history is unacceptable

## Decision 5: WASM Executables Needed

**Decision**: 4 WASM executables to replace all JS crypto:

| Executable | Replaces | Input (stdin JSON) | Output (stdout JSON) |
|-----------|----------|-------------------|---------------------|
| `inspect-address.wasm` | Inspect.js, Bech32.js, Base58.js, CBOR decoder | `{"address": "addr1q..."}` | Address inspection JSON |
| `derive-key.wasm` | Derivation.js, Bootstrap.js, Mnemonic.js, Hash.js | `{"mnemonic": "...", "path": "1852H/1815H/0H/0/0", "style": "shelley"}` | Key bytes (hex-encoded) |
| `make-address.wasm` | Shelley.js | `{"payment_key": "...", "stake_key": "...", "network": "mainnet", "type": "base"}` | Bech32 address |
| `sign-message.wasm` | Signing.js | `{"key": "...", "message": "..."}` | Signature (hex) |

**Rationale**: One executable per logical operation. `inspect-address` already exists. The others follow the same pattern.

## Decision 6: Handling `@scure/bip39` (Mnemonic Validation)

**Decision**: Mnemonic entropy extraction moves into `derive-key.wasm`. The PureScript Mnemonic module is simplified to pass raw mnemonic text to WASM.

**Rationale**:
- The Haskell library already handles mnemonic-to-entropy conversion
- No need for a separate WASM executable just for mnemonic validation
- The `derive-key.wasm` takes mnemonic as input and handles everything internally

## Decision 7: Bundle Size Impact

**Decision**: WASM binaries are loaded separately from the main JS bundle. The JS bundle shrinks (fewer dependencies). Total page weight increases but is acceptable.

**Rationale**:
- Current JS bundle: ~200KB gzipped (estimate)
- After migration: ~100KB gzipped JS + ~5MB WASM (loaded on demand, gzipped ~1.5MB)
- WASM loaded only when first operation is triggered, not on page load
- Developer tool — users expect heavier pages; correctness matters more than load time

## Decision 8: cabal-wasm.project Dependencies

**Decision**: Use the existing patched dependency set from `cabal-wasm.project` in paolino/cardano-addresses.

**Key patches required for WASM compilation**:
- `cborg`: GHC 9.12 WASM fix for GHC.IntWord64
- `ram`: WASI mmap emulation (`-lwasi-emulated-mman`)
- `crypton >= 1.1`: uses `ram` instead of `memory`, argon2 no-threads
- `formatting`: `+no-double-conversion` flag

These are already proven and maintained in the existing WASM branch.
