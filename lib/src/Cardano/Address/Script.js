const fail = (message) => {
  throw new Error(message);
};

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
    case 0:
      return readLength(bytes, state, additional);
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

const expectArray = (value, message) => {
  if (!Array.isArray(value)) {
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

const expectNumber = (value, message) => {
  if (!Number.isInteger(value) || value < 0) {
    fail(message);
  }

  return value;
};

const issue = (level, code, message) => ({ level, code, message });

const parseScript = (value) => {
  const script = expectArray(value, "Native script must decode to a CBOR array.");
  const tag = expectNumber(script[0], "Native script tag must be a non-negative integer.");

  switch (tag) {
    case 0: {
      if (script.length !== 2) {
        fail("Signature script must be a 2-element array.");
      }

      const keyHash = expectBytes(script[1], "Signature script key hash must be bytes.");

      if (keyHash.length !== 28) {
        fail("Signature script key hash must be 28 bytes.");
      }

      return { kind: "Signature", keyHashHex: Array.from(keyHash, (byte) => byte.toString(16).padStart(2, "0")).join("") };
    }
    case 1:
    case 2: {
      if (script.length !== 2) {
        fail(`${tag === 1 ? "All" : "Any"} script must be a 2-element array.`);
      }

      return {
        kind: tag === 1 ? "All" : "Any",
        scripts: expectArray(script[1], "Script list must be an array.").map(parseScript),
      };
    }
    case 3: {
      if (script.length !== 3) {
        fail("At least script must be a 3-element array.");
      }

      return {
        kind: "AtLeast",
        required: expectNumber(script[1], "At least script threshold must be a non-negative integer."),
        scripts: expectArray(script[2], "At least script list must be an array.").map(parseScript),
      };
    }
    case 4:
    case 5: {
      if (script.length !== 2) {
        fail(`${tag === 4 ? "Active from" : "Active until"} script must be a 2-element array.`);
      }

      return {
        kind: tag === 4 ? "ActiveFrom" : "ActiveUntil",
        slot: expectNumber(script[1], "Timelock slot must be a non-negative integer."),
      };
    }
    default:
      fail(`Unsupported native script tag: ${tag}`);
  }
};

const collectSignatureHexes = (script, into = []) => {
  switch (script.kind) {
    case "Signature":
      into.push(script.keyHashHex);
      break;
    case "All":
    case "Any":
      script.scripts.forEach((child) => collectSignatureHexes(child, into));
      break;
    case "AtLeast":
      script.scripts.forEach((child) => collectSignatureHexes(child, into));
      break;
    default:
      break;
  }

  return into;
};

const summarizeTimelocks = (script) => {
  if (script.kind !== "All") {
    return { activeFrom: [], activeUntil: [] };
  }

  const activeFrom = [];
  const activeUntil = [];

  for (const child of script.scripts) {
    if (child.kind === "ActiveFrom") {
      activeFrom.push(child.slot);
    } else if (child.kind === "ActiveUntil") {
      activeUntil.push(child.slot);
    }
  }

  return { activeFrom, activeUntil };
};

const validateScript = (script) => {
  const issues = [];
  const isTimelock = (node) =>
    node.kind === "ActiveFrom" || node.kind === "ActiveUntil";

  const visit = (node) => {
    switch (node.kind) {
      case "All":
      case "Any": {
        if (node.scripts.length === 0) {
          issues.push(issue("recommended", "empty-list", "Script list should not be empty."));
        }

        node.scripts.forEach(visit);

        const signatureHexes = collectSignatureHexes(node);
        if (new Set(signatureHexes).size !== signatureHexes.length) {
          issues.push(issue("recommended", "duplicate-signatures", "Script repeats the same signature requirement."));
        }

        if (node.kind === "Any" && node.scripts.some(isTimelock)) {
          issues.push(issue("recommended", "redundant-timelocks", "Script contains redundant timelock constraints."));
          break;
        }

        if (node.kind === "All" && node.scripts.length > 0 && node.scripts.every(isTimelock)) {
          issues.push(issue("recommended", "empty-list", "Script list should not be empty."));
          break;
        }

        const { activeFrom, activeUntil } = summarizeTimelocks(node);
        if (activeFrom.length > 1 || activeUntil.length > 1) {
          issues.push(issue("recommended", "redundant-timelocks", "Script contains redundant timelock constraints."));
        }
        if (
          activeFrom.length > 0 &&
          activeUntil.length > 0 &&
          Math.max(...activeFrom) >= Math.min(...activeUntil)
        ) {
          issues.push(issue("recommended", "timelock-trap", "Timelock constraints cannot be satisfied together."));
        }
        break;
      }
      case "AtLeast": {
        if (node.scripts.length === 0) {
          issues.push(issue("recommended", "empty-list", "Script list should not be empty."));
        }
        if (node.required === 0) {
          issues.push(issue("recommended", "m-zero", "At least scripts should require at least one branch."));
        }
        if (node.required > node.scripts.length) {
          issues.push(issue("recommended", "list-too-small", "At least threshold exceeds the number of child scripts."));
        }

        node.scripts.forEach(visit);

        const signatureHexes = collectSignatureHexes(node);
        if (new Set(signatureHexes).size !== signatureHexes.length) {
          issues.push(issue("recommended", "duplicate-signatures", "Script repeats the same signature requirement."));
        }
        break;
      }
      default:
        break;
    }
  };

  visit(script);
  return issues;
};

const rootTypeLabel = (script) => {
  switch (script.kind) {
    case "Signature":
      return "Signature";
    case "All":
      return "All";
    case "Any":
      return "Any";
    case "AtLeast":
      return "At least";
    case "ActiveFrom":
      return "Active from slot";
    case "ActiveUntil":
      return "Active until slot";
    default:
      return script.kind;
  }
};

export const analyzeNativeScriptImpl = (onLeft) => (onRight) => (bytes) => {
  try {
    if (bytes.length === 0) {
      fail("Native script bytes are empty.");
    }

    const cborBytes = bytes[0] === 0 ? bytes.slice(1) : bytes;
    const decoded = decodeSingle(cborBytes);
    const script = parseScript(decoded);
    const issues = validateScript(script);

    return onRight({
      scriptType: rootTypeLabel(script),
      validationStatus: issues.length === 0 ? "valid" : "warning",
      issues,
    });
  } catch (error) {
    return onLeft(
      error instanceof Error ? error.message : "Failed to analyze native script.",
    );
  }
};
