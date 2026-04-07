import cardanoCrypto from "cardano-crypto.js";
import { Buffer } from "buffer";

const DERIVATION_SCHEME_BYRON = 1;
const DERIVATION_SCHEME_ICARUS = 2;
const HARDENED = 0x80000000;

globalThis.Buffer = globalThis.Buffer ?? Buffer;

const toBuffer = (bytes) => Buffer.from(bytes);

const parsePathSegment = (value) => {
  const trimmed = value.trim();
  const hardened = /h$/i.test(trimmed);
  const digits = hardened ? trimmed.slice(0, -1) : trimmed;

  if (!/^\d+$/.test(digits)) {
    throw new Error(`Invalid Byron path segment: ${value}`);
  }

  const index = Number.parseInt(digits, 10);

  if (!Number.isSafeInteger(index) || index < 0 || index > 0x7fffffff) {
    throw new Error(`Out-of-range Byron path segment: ${value}`);
  }

  return hardened ? HARDENED + index : index;
};

const parseDerivationPath = (derivationPath) => {
  const segments = derivationPath.split("/");

  if (segments.length !== 2) {
    throw new Error(
      `Expected Byron derivation path with 2 segments, got: ${derivationPath}`,
    );
  }

  return segments.map(parsePathSegment);
};

export const constructIcarusAddressImpl = (protocolMagic) => (xpub) =>
  cardanoCrypto.packBootstrapAddress(
    [],
    toBuffer(xpub),
    Buffer.alloc(0),
    DERIVATION_SCHEME_ICARUS,
    protocolMagic,
  );

export const constructByronAddressImpl =
  (protocolMagic) => (addressXPub) => (rootXPub) => (derivationPath) => async () => {
    const hdPassphrase = Buffer.from(
      await cardanoCrypto.xpubToHdPassphrase(toBuffer(rootXPub)),
    );

    return cardanoCrypto.packBootstrapAddress(
      parseDerivationPath(derivationPath),
      toBuffer(addressXPub),
      hdPassphrase,
      DERIVATION_SCHEME_BYRON,
      protocolMagic,
    );
  };
