# Data Model: Replace JS Crypto with WASM

## Entities

### WasmModule

Represents a compiled WebAssembly module cached in the browser.

- `name :: String` — executable name (e.g., "inspect-address")
- `module :: WebAssembly.Module` — compiled module (reusable across calls)
- `status :: Loading | Ready | Failed String` — initialization state

### WasmRequest

JSON payload sent to a WASM executable via stdin.

- `command :: String` — operation identifier (implicit from which WASM is called)
- `payload :: JSON` — operation-specific input data

### WasmResponse

JSON payload received from WASM executable via stdout.

- `success :: Boolean` — whether the operation succeeded
- `result :: JSON` — operation-specific output data
- `error :: Maybe String` — error message if failed

## Protocol Schemas

### inspect-address

**Input** (stdin):
```json
"addr1q..."
```
Raw address string (bech32, base58, or hex). No JSON wrapping — matches existing `inspect-address.wasm` behavior.

**Output** (stdout):
```json
{
  "address_style": "Shelley",
  "network_tag": 1,
  "stake_reference": "by value",
  "address_type": 0,
  "spending_key_hash": "abc123...",
  "spending_key_hash_bech32": "addr_vkh1...",
  "stake_key_hash": "def456...",
  "stake_key_hash_bech32": "stake_vkh1..."
}
```

### derive-key

**Input** (stdin):
```json
{
  "mnemonic": "exercise club noble adult miracle ...",
  "passphrase": "",
  "style": "shelley",
  "path": "1852H/1815H/0H/0/0"
}
```

**Output** (stdout):
```json
{
  "extended_signing_key": "hex...",
  "extended_verification_key": "hex...",
  "key_hash": "hex...",
  "bech32_signing_key": "addr_xsk1...",
  "bech32_verification_key": "addr_xvk1..."
}
```

### make-address

**Input** (stdin):
```json
{
  "type": "base",
  "network": "mainnet",
  "payment_key_hash": "hex...",
  "stake_key_hash": "hex..."
}
```

**Output** (stdout):
```json
{
  "address_bech32": "addr1q...",
  "address_hex": "hex..."
}
```

### sign-message

**Input** (stdin):
```json
{
  "signing_key": "hex...",
  "message": "hex..."
}
```

**Output** (stdout):
```json
{
  "signature": "hex...",
  "verification_key": "hex..."
}
```

## State Transitions

### WASM Module Lifecycle

```
[Page Load] → Loading → Ready → [Available for calls]
                     ↘ Failed(error) → [Show error to user, retry on next call]
```

### Operation Call Flow

```
[User input] → Serialize JSON → Write to WASI stdin → Start WASM
            → Read stdout → Parse JSON → Update UI
            → (on error) Read stderr → Show error
```

## Relationships

- Each PureScript FFI function maps to exactly one WASM executable call
- The `WasmModule` is shared across all calls to the same executable (module compiled once)
- WASI FDs (stdin/stdout/stderr) are created fresh per invocation
- The PureScript types (`InspectResult`, `DerivedKey`, `Address`, `Signature`) remain unchanged — only the JS FFI implementation changes
