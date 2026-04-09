import { WASI, File, OpenFile, ConsoleStdout } from "@bjorn3/browser_wasi_shim";

const moduleCache = new Map();

export const loadWasmModuleImpl = (onError) => (onSuccess) => (url) => async () => {
  try {
    const cached = moduleCache.get(url);
    if (cached) {
      return onSuccess(cached);
    }
    const response = await fetch(url);
    if (!response.ok) {
      return onError(`Failed to fetch WASM: HTTP ${response.status}`);
    }
    const bytes = await response.arrayBuffer();
    const mod = await WebAssembly.compile(bytes);
    moduleCache.set(url, mod);
    return onSuccess(mod);
  } catch (e) {
    return onError(e.message || "Failed to load WASM module");
  }
};

export const callWasmImpl = (onError) => (onSuccess) => (wasmModule) => (input) => async () => {
  try {
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
    const instance = await WebAssembly.instantiate(wasmModule, {
      wasi_snapshot_preview1: wasi.wasiImport,
    });
    wasi.start(instance);

    if (stdoutBuf) {
      return onSuccess(stdoutBuf.trim());
    }
    return onError(stderrBuf.trim() || "WASM produced no output");
  } catch (e) {
    return onError(e.message || "WASM execution failed");
  }
};
