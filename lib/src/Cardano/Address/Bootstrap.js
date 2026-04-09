import { callWasm } from "./Wasm.js";

const bytesToHex = (bytes) =>
  Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");

export const constructIcarusAddressImpl = (protocolMagic) => (xpub) => async () => {
  const jsonStr = await callWasm(JSON.stringify({
    cmd: "bootstrap-address",
    style: "icarus",
    protocol_magic: protocolMagic,
    xpub: bytesToHex(xpub),
  }));
  const result = JSON.parse(jsonStr);
  return result.address_base58;
};

export const constructByronAddressImpl = (protocolMagic) => (addressXPub) => (rootXPub) => (derivationPath) => async () => {
  const jsonStr = await callWasm(JSON.stringify({
    cmd: "bootstrap-address",
    style: "byron",
    protocol_magic: protocolMagic,
    xpub: bytesToHex(addressXPub),
    root_xpub: bytesToHex(rootXPub),
    derivation_path: derivationPath,
  }));
  const result = JSON.parse(jsonStr);
  return result.address_base58;
};

export const constructIcarusAddressFromMnemonicImpl = (protocolMagic) => (mnemonic) => (accountIndex) => (role) => (addressIndex) => async () => {
  const jsonStr = await callWasm(JSON.stringify({
    cmd: "bootstrap-address",
    style: "icarus-from-mnemonic",
    protocol_magic: protocolMagic,
    mnemonic,
    account_index: accountIndex,
    role,
    address_index: addressIndex,
  }));
  const result = JSON.parse(jsonStr);
  return result.address_base58;
};

export const constructByronAddressFromMnemonicImpl = (protocolMagic) => (mnemonic) => (accountIndex) => (addressIndex) => async () => {
  const jsonStr = await callWasm(JSON.stringify({
    cmd: "bootstrap-address",
    style: "byron-from-mnemonic",
    protocol_magic: protocolMagic,
    mnemonic,
    account_index: accountIndex,
    address_index: addressIndex,
  }));
  const result = JSON.parse(jsonStr);
  return result.address_base58;
};
