import cardanoCrypto from "cardano-crypto.js";
import { Buffer } from "buffer";

const DERIVATION_SCHEME_BYRON = 1;
const DERIVATION_SCHEME_ICARUS = 2;
const HARDENED = 0x80000000;
const PURPOSE_44 = 44;
const COIN_TYPE_ADA = 1815;

globalThis.Buffer = globalThis.Buffer ?? Buffer;

const toBuffer = (bytes) => Buffer.from(bytes);

const toXPub = (xprv) => {
  const publicKey = cardanoCrypto.toPublic(xprv.slice(0, 64));
  const chainCode = xprv.slice(96, 128);
  return Buffer.concat([publicKey, chainCode]);
};

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

export const constructIcarusAddressFromMnemonicImpl =
  (protocolMagic) =>
  (mnemonic) =>
  (accountIndex) =>
  (role) =>
  (addressIndex) =>
  async () => {
    const rootKey = Buffer.from(
      await cardanoCrypto.mnemonicToRootKeypair(mnemonic, DERIVATION_SCHEME_ICARUS),
    );
    const purposeKey = cardanoCrypto.derivePrivate(
      rootKey,
      HARDENED + PURPOSE_44,
      DERIVATION_SCHEME_ICARUS,
    );
    const coinTypeKey = cardanoCrypto.derivePrivate(
      purposeKey,
      HARDENED + COIN_TYPE_ADA,
      DERIVATION_SCHEME_ICARUS,
    );
    const accountKey = cardanoCrypto.derivePrivate(
      coinTypeKey,
      HARDENED + accountIndex,
      DERIVATION_SCHEME_ICARUS,
    );
    const roleKey = cardanoCrypto.derivePrivate(
      accountKey,
      role,
      DERIVATION_SCHEME_ICARUS,
    );
    const addressKey = cardanoCrypto.derivePrivate(
      roleKey,
      addressIndex,
      DERIVATION_SCHEME_ICARUS,
    );

    return constructIcarusAddressImpl(protocolMagic)(toXPub(addressKey));
  };

export const constructByronAddressFromMnemonicImpl =
  (protocolMagic) => (mnemonic) => (accountIndex) => (addressIndex) => async () => {
    const rootKey = Buffer.from(
      await cardanoCrypto.mnemonicToRootKeypair(mnemonic, DERIVATION_SCHEME_BYRON),
    );
    const rootXPub = toXPub(rootKey);
    const accountKey = cardanoCrypto.derivePrivate(
      rootKey,
      HARDENED + accountIndex,
      DERIVATION_SCHEME_BYRON,
    );
    const addressKey = cardanoCrypto.derivePrivate(
      accountKey,
      addressIndex,
      DERIVATION_SCHEME_BYRON,
    );
    const addressXPub = toXPub(addressKey);

    return constructByronAddressImpl(protocolMagic)(
      addressXPub,
    )(rootXPub)(`${accountIndex}H/${addressIndex}`)();
  };
