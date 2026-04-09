import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";

let wasmModule = null;

const ensureModule = async () => {
  if (wasmModule) return wasmModule;
  const response = await fetch("wasm/cardano-addresses.wasm");
  if (!response.ok) throw new Error(`Failed to fetch WASM: HTTP ${response.status}`);
  const bytes = await response.arrayBuffer();
  wasmModule = await WebAssembly.compile(bytes);
  return wasmModule;
};

const callWasm = async (input) => {
  const mod = await ensureModule();
  const encoder = new TextEncoder();
  const stdinData = encoder.encode(input);

  let stdoutBuf = "";
  let stderrBuf = "";

  const fds = [
    new OpenFile(new File(stdinData)),
    ConsoleStdout.lineBuffered((line) => { stdoutBuf += line + "\n"; }),
    ConsoleStdout.lineBuffered((line) => { stderrBuf += line + "\n"; }),
  ];

  const wasi = new WASI([], [], fds, { debug: false });
  const instance = await WebAssembly.instantiate(mod, {
    wasi_snapshot_preview1: wasi.wasiImport,
  });
  wasi.start(instance);

  if (stdoutBuf) return stdoutBuf.trim();
  throw new Error(stderrBuf.trim() || "WASM produced no output");
};

const bytesToHex = (bytes) =>
  Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

const encoder = new TextEncoder();

export const encodeUtf8Impl = (value) => encoder.encode(value);

export const signSerializedXPrvWasmImpl = (onLeft) => (onRight) => (serializedXPrvHex) => (payloadHex) => async () => {
  try {
    const jsonStr = await callWasm(JSON.stringify({
      cmd: "sign",
      key: serializedXPrvHex,
      message: payloadHex,
    }));
    const result = JSON.parse(jsonStr);
    return onRight({
      signatureHex: result.signature,
      verificationKeyHex: result.verification_key,
    });
  } catch (e) {
    return onLeft(e.message || "Signing failed");
  }
};

export const verifyXPubWasmImpl = (onLeft) => (onRight) => (verificationKeyHex) => (payloadHex) => (signatureHex) => async () => {
  try {
    const jsonStr = await callWasm(JSON.stringify({
      cmd: "verify",
      key: verificationKeyHex,
      message: payloadHex,
      signature: signatureHex,
    }));
    const result = JSON.parse(jsonStr);
    return onRight(result.valid);
  } catch (e) {
    return onLeft(e.message || "Verification failed");
  }
};
