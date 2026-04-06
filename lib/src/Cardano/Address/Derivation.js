import cardanoCrypto from "cardano-crypto.js";
import { Buffer } from "buffer";
import { mnemonicToEntropy } from "@scure/bip39";
import { wordlist } from "@scure/bip39/wordlists/english";

globalThis.Buffer = globalThis.Buffer ?? Buffer;

const DERIVATION_SCHEME = 2;
const HARDENED = 0x80000000;
const PURPOSE_1852 = 1852;
const COIN_TYPE_ADA = 1815;
const ROLE_EXTERNAL = 0;
const ROLE_STAKE = 2;

const derivePrivate = (parentKey, index) =>
  cardanoCrypto.derivePrivate(parentKey, index, DERIVATION_SCHEME);

export const deriveRootKeyImpl = (mnemonic) => async () => {
  const entropyHex = mnemonicToEntropy(mnemonic, wordlist);
  const seed = Buffer.from(entropyHex, "hex");
  const passwordKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(""),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      hash: "SHA-512",
      salt: seed,
      iterations: 4096,
    },
    passwordKey,
    96 * 8,
  );
  const xprv = new Uint8Array(bits);

  xprv[0] &= 248;
  xprv[31] &= 31;
  xprv[31] |= 64;

  const xprvBuffer = Buffer.from(xprv);
  const publicKey = cardanoCrypto.toPublic(xprvBuffer.slice(0, 64));
  return Buffer.concat([xprvBuffer.slice(0, 64), publicKey, xprvBuffer.slice(64)]);
};

export const deriveAccountKeyImpl = (rootKey) => (accountIndex) => {
  const purposeKey = derivePrivate(rootKey, HARDENED + PURPOSE_1852);
  const coinTypeKey = derivePrivate(purposeKey, HARDENED + COIN_TYPE_ADA);
  return derivePrivate(coinTypeKey, HARDENED + accountIndex);
};

export const deriveAddressKeyImpl = (accountKey) => (role) => (addressIndex) => {
  const roleKey = derivePrivate(accountKey, role);
  return derivePrivate(roleKey, addressIndex);
};

export const deriveStakeKeyImpl = (accountKey) => {
  const roleKey = derivePrivate(accountKey, ROLE_STAKE);
  return derivePrivate(roleKey, 0);
};

export const toXPubImpl = (xprv) => {
  const publicKey = cardanoCrypto.toPublic(xprv.slice(0, 64));
  const chainCode = xprv.slice(96, 128);
  return new Uint8Array([...publicKey, ...chainCode]);
};

export const serializeXPrvImpl = (xprv) =>
  new Uint8Array([
    ...xprv.slice(0, 64),
    ...xprv.slice(96, 128),
  ]);
