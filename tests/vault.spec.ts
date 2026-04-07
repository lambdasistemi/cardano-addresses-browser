import { expect, test } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

const fixture = JSON.parse(
  fs.readFileSync(path.join(process.cwd(), "test-vectors", "vectors.json"), "utf8"),
);

const signingVector = fixture.signingVectors.find(
  (candidate: { label: string }) => candidate.label === "message-sign-address-hex",
);

if (!signingVector) {
  throw new Error("Missing signing fixture: message-sign-address-hex");
}

test("vault stores mnemonic and signing secrets without clipboard roundtrips", async ({
  page,
}) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Vault Encrypted file storage/ }).click();
  await expect(page.locator(".page-title")).toHaveText("Encrypted Vault");
  await page.getByPlaceholder("Strong passphrase for the vault file").fill("correct horse battery staple");
  await page.getByPlaceholder("Repeat the vault passphrase").fill("correct horse battery staple");
  await page.getByRole("button", { name: "Show passphrase" }).click();
  await page.getByRole("button", { name: "Create vault" }).click();
  await expect(page.getByText("Unlocked, modified in memory")).toBeVisible();

  await page.getByRole("button", { name: /Mnemonic Generate and hand off/ }).click();
  await page.getByRole("button", { name: "12 words" }).click();
  await page.getByRole("button", { name: "Generate phrase" }).click();
  await page.getByPlaceholder("12-word mnemonic").fill("Paper backup");
  await page.getByRole("button", { name: "Save to vault" }).click();
  await expect(page.getByText("Saved Paper backup into the unlocked vault.")).toBeVisible();

  await page.getByRole("button", { name: /Restore Choose family first/ }).click();
  const restoreCard = page.locator("section.card").filter({ has: page.getByText("Restore and build") });
  await expect(restoreCard.locator(".vault-entry").getByText("Paper backup", { exact: true })).toBeVisible();
  await restoreCard.getByRole("button", { name: "Use in Restore" }).click();
  await expect(
    page.locator('[placeholder="abandon abandon ... or use the generated phrase"]'),
  ).toHaveValue(/.+/);

  await page.getByRole("button", { name: /Signing Sign and verify/ }).click();
  const signCard = page.locator("section.card").filter({ has: page.getByText("Sign payload") });
  await signCard.getByRole("button", { name: "Show signing key" }).click();
  await signCard.getByPlaceholder("addr_xsk1... or stake_xsk1...").fill(signingVector.signingKeyBech32);
  await signCard.getByPlaceholder("Signing key").fill("Ops signer");
  await signCard.getByRole("button", { name: "Save signing key to vault" }).click();
  await expect(page.getByText("Saved Ops signer into the unlocked vault.")).toBeVisible();
  await signCard.getByPlaceholder("addr_xsk1... or stake_xsk1...").fill("");
  await expect(signCard.locator(".vault-entry").getByText("Ops signer", { exact: true })).toBeVisible();
  await signCard.locator(".vault-entry").filter({ has: page.getByText("Ops signer", { exact: true }) }).getByRole("button", { name: "Use in Signing" }).click();
  await expect(signCard.getByPlaceholder("addr_xsk1... or stake_xsk1...")).toHaveValue(
    signingVector.signingKeyBech32,
  );
});

test("vault exports and reimports encrypted file contents", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Vault Encrypted file storage/ }).click();
  await expect(page.locator(".page-title")).toHaveText("Encrypted Vault");
  await page.getByPlaceholder("Strong passphrase for the vault file").fill("correct horse battery staple");
  await page.getByPlaceholder("Repeat the vault passphrase").fill("correct horse battery staple");
  await page.getByRole("button", { name: "Create vault" }).click();

  await page.getByRole("button", { name: /Mnemonic Generate and hand off/ }).click();
  await page.getByRole("button", { name: "12 words" }).click();
  await page.getByRole("button", { name: "Generate phrase" }).click();
  await page.getByPlaceholder("12-word mnemonic").fill("Importable phrase");
  await page.getByRole("button", { name: "Save to vault" }).click();

  await page.getByRole("button", { name: /Vault Encrypted file storage/ }).click();
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export vault file" }).click();
  const download = await downloadPromise;
  const downloadedPath = await download.path();
  if (!downloadedPath) {
    throw new Error("Expected exported vault file to exist on disk.");
  }

  await page.getByRole("button", { name: "Lock vault" }).click();
  await expect(page.locator(".kv-row").filter({ has: page.getByText("State") }).getByText("Locked")).toBeVisible();

  const fileChooserPromise = page.waitForEvent("filechooser");
  await page.getByRole("button", { name: "Import vault file" }).click();
  const fileChooser = await fileChooserPromise;
  await fileChooser.setFiles(downloadedPath);

  await expect(page.locator(".kv-row").filter({ has: page.getByText("State") }).getByText("Unlocked")).toBeVisible();
  const entriesCard = page.locator("section.card").filter({ has: page.getByText("Unlocked entries") });
  await expect(entriesCard.getByText("Importable phrase", { exact: true })).toBeVisible();
});
