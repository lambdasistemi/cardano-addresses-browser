import cardanoCrypto from "cardano-crypto.js";
import { Buffer } from "buffer";

globalThis.Buffer = globalThis.Buffer ?? Buffer;

const encoder = new TextEncoder();

const verificationKeyFromSerializedXPrv = (serializedXPrv) => {
  const privateKey = serializedXPrv.slice(0, 64);
  const chainCode = serializedXPrv.slice(64, 96);
  const publicKey = cardanoCrypto.toPublic(Buffer.from(privateKey));
  return new Uint8Array([...publicKey, ...chainCode]);
};

const keypairFromSerializedXPrv = (serializedXPrv) => {
  const privateKey = serializedXPrv.slice(0, 64);
  const chainCode = serializedXPrv.slice(64, 96);
  const publicKey = cardanoCrypto.toPublic(Buffer.from(privateKey));
  return new Uint8Array([...privateKey, ...publicKey, ...chainCode]);
};

export const encodeUtf8Impl = (value) => encoder.encode(value);

export const signSerializedXPrvImpl = (serializedXPrv) => (payload) =>
  Uint8Array.from(cardanoCrypto.sign(Buffer.from(payload), Buffer.from(keypairFromSerializedXPrv(serializedXPrv))));

export const verificationKeyFromSerializedXPrvImpl = (serializedXPrv) =>
  verificationKeyFromSerializedXPrv(serializedXPrv);

export const verifyXPubImpl = (payload) => (verificationKey) => (signature) =>
  cardanoCrypto.verify(
    Buffer.from(payload),
    Buffer.from(verificationKey.slice(0, 32)),
    Buffer.from(signature),
  );
