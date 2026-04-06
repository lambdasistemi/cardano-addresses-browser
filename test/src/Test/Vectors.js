import fs from "node:fs";
import path from "node:path";
import { Just, Nothing } from "../Data.Maybe/index.js";

const fixturePath = path.join(process.cwd(), "test-vectors", "vectors.json");
const fixture = JSON.parse(fs.readFileSync(fixturePath, "utf8"));

export const derivationVectors = fixture.derivationVectors;

const toMaybe = (value) => (value == null ? Nothing.value : Just.create(value));

export const inspectionVectors = fixture.inspectionVectors.map((vector) => ({
  ...vector,
  expected: {
    ...vector.expected,
    spendingKeyHash: toMaybe(vector.expected.spendingKeyHash),
    stakeKeyHash: toMaybe(vector.expected.stakeKeyHash),
    spendingScriptHash: toMaybe(vector.expected.spendingScriptHash),
    stakeScriptHash: toMaybe(vector.expected.stakeScriptHash),
  },
}));

export const scriptHashVectors = fixture.scriptHashVectors;
