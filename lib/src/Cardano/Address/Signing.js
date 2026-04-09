import { callWasm } from "./Wasm.js";

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
