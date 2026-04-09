import { callWasm } from "./Wasm.js";
import { bech32 } from "bech32";

const hexToBytes = (hex) =>
  Uint8Array.from(hex.match(/.{2}/g).map((b) => parseInt(b, 16)));

const toBech32 = (hrp, hexKey) => {
  const bytes = hexToBytes(hexKey);
  return bech32.encode(hrp, bech32.toWords(bytes), 1023);
};

export const derivePipelineImpl = (onError) => (onSuccess) => (mnemonic) => (accountIndex) => (role) => (addressIndex) => async () => {
  try {
    const path = `1852H/1815H/${accountIndex}H/${role}/${addressIndex}`;
    const input = JSON.stringify({ cmd: "derive", mnemonic, path });
    const jsonStr = await callWasm(input);
    const keys = JSON.parse(jsonStr);

    return onSuccess({
      rootKeyBech32: toBech32("root_xsk", keys.root_xsk),
      accountKeyBech32: toBech32("acct_xsk", keys.acct_xsk),
      addressKeyBech32: toBech32(role === 2 ? "stake_xsk" : "addr_xsk", keys.addr_xsk),
      addressPublicKeyBech32: toBech32(role === 2 ? "stake_xvk" : "addr_xvk", keys.addr_xvk),
      stakeKeyBech32: toBech32("stake_xsk", keys.stake_xsk),
      stakePublicKeyBech32: toBech32("stake_xvk", keys.stake_xvk),
    });
  } catch (e) {
    return onError(e.message || "Key derivation failed");
  }
};
