const fail = (message) => {
  throw new Error(message);
};

const toHex = (bytes) =>
  Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");

const readLength = (bytes, state, additional) => {
  if (additional < 24) {
    return additional;
  }

  const readByte = () => {
    if (state.offset >= bytes.length) {
      fail("Unexpected end of CBOR input.");
    }

    return bytes[state.offset++];
  };

  if (additional === 24) {
    return readByte();
  }

  if (additional === 25) {
    return (readByte() << 8) | readByte();
  }

  if (additional === 26) {
    return (
      readByte() * 0x1000000 +
      (readByte() << 16) +
      (readByte() << 8) +
      readByte()
    );
  }

  fail(`Unsupported CBOR additional info: ${additional}`);
};

const decodeItem = (bytes, state) => {
  if (state.offset >= bytes.length) {
    fail("Unexpected end of CBOR input.");
  }

  const initial = bytes[state.offset++];
  const major = initial >> 5;
  const additional = initial & 0x1f;

  switch (major) {
    case 0: {
      return readLength(bytes, state, additional);
    }
    case 2: {
      const length = readLength(bytes, state, additional);
      const start = state.offset;
      const end = start + length;

      if (end > bytes.length) {
        fail("Unexpected end of CBOR byte string.");
      }

      state.offset = end;
      return bytes.slice(start, end);
    }
    case 4: {
      const length = readLength(bytes, state, additional);
      const items = [];

      for (let index = 0; index < length; index += 1) {
        items.push(decodeItem(bytes, state));
      }

      return items;
    }
    case 5: {
      const length = readLength(bytes, state, additional);
      const entries = [];

      for (let index = 0; index < length; index += 1) {
        entries.push([decodeItem(bytes, state), decodeItem(bytes, state)]);
      }

      return entries;
    }
    case 6: {
      const tag = readLength(bytes, state, additional);
      return { tag, value: decodeItem(bytes, state) };
    }
    default:
      fail(`Unsupported CBOR major type: ${major}`);
  }
};

const decodeSingle = (bytes) => {
  const state = { offset: 0 };
  const value = decodeItem(bytes, state);

  if (state.offset !== bytes.length) {
    fail("Unconsumed bytes remaining after CBOR decode.");
  }

  return value;
};

const expectArray = (value, length, message) => {
  if (!Array.isArray(value) || value.length !== length) {
    fail(message);
  }

  return value;
};

const expectBytes = (value, message) => {
  if (!(value instanceof Uint8Array)) {
    fail(message);
  }

  return value;
};

const expectTaggedBytes = (value, message) => {
  if (
    value == null ||
    typeof value !== "object" ||
    !("value" in value) ||
    !(value.value instanceof Uint8Array)
  ) {
    fail(message);
  }

  return value.value;
};

const expectNumber = (value, message) => {
  if (typeof value !== "number") {
    fail(message);
  }

  return value;
};

const parseAttributes = (value) => {
  const attributes = new Map();

  for (const entry of value) {
    if (!Array.isArray(entry) || entry.length !== 2) {
      fail("Invalid legacy address attributes.");
    }

    const [key, attrValue] = entry;
    attributes.set(expectNumber(key, "Legacy attribute key must be numeric."), expectBytes(attrValue, "Legacy attribute must be bytes."));
  }

  return attributes;
};

const networkTagFromAttributes = (attributes) => {
  const payload = attributes.get(2);

  if (payload == null) {
    return -1;
  }

  return expectNumber(
    decodeSingle(payload),
    "Legacy protocol magic attribute must decode to a number.",
  );
};

const parseLegacyAddress = (bytes) => {
  const wrapper = expectArray(
    decodeSingle(bytes),
    2,
    "Legacy address must be a CBOR list of length 2.",
  );
  const payload = expectTaggedBytes(
    wrapper[0],
    "Legacy address payload must be a tagged byte string.",
  );
  const inner = expectArray(
    decodeSingle(payload),
    3,
    "Legacy address payload must be a CBOR list of length 3.",
  );

  const addressRoot = expectBytes(inner[0], "Legacy address root must be bytes.");
  const attributes = parseAttributes(inner[1]);

  return {
    addressRoot,
    attributes,
    networkTag: networkTagFromAttributes(attributes),
  };
};

export const inspectLegacyAddressImpl = (onLeft) => (onRight) => (bytes) => {
  try {
    const legacy = parseLegacyAddress(bytes);
    const derivationPath = legacy.attributes.get(1);
    const isByron = derivationPath != null;

    return onRight({
      addressStyle: isByron ? "Byron" : "Icarus",
      networkTag: legacy.networkTag,
      extraDetails: isByron
        ? [
            { label: "Address root", value: toHex(legacy.addressRoot) },
            {
              label: "Encrypted derivation path",
              value: toHex(derivationPath),
            },
          ]
        : [{ label: "Address root", value: toHex(legacy.addressRoot) }],
    });
  } catch (error) {
    return onLeft(
      error instanceof Error
        ? error.message
        : "Failed to inspect legacy address.",
    );
  }
};
