import { expect, test } from "@playwright/test";

const validScriptCborHex =
  "008200581c3207c32d806ec2cabc78ff7ed869bd3098b7db93c43cc8aa93ab59eb";
const validScriptJson =
  '"addr_vkh1xgruxtvqdmpv40rclalds6daxzvt0kuncs7v325n4dv7kz46hgj"';
const validScriptHashHex =
  "558ba956d2a19cecd37cb49d3f0ddff1985013dd86e695128bc3d996";
const validScriptHashBech32 =
  "script12k96j4kj5xwwe5mukjwn7rwl7xv9qy7asmnf2y5tc0vevku89av";
const warningScriptCborHex =
  "008202838200581c3207c32d806ec2cabc78ff7ed869bd3098b7db93c43cc8aa93ab59eb8204182a82051901f4";
const warningScriptHashHex =
  "677ee2d9c71c40eff5a252dba6e4289f03f590d67824f7b7282bf253";

test("scripts page analyzes valid native script CBOR", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Scripts Hash native scripts/ }).click();
  await expect(page.getByRole("heading", { name: "Native Scripts" })).toBeVisible();

  await page.getByPlaceholder("8200581c...").fill(validScriptCborHex);

  await expect(page.getByText("Signature", { exact: true })).toBeVisible();
  await expect(page.getByText("valid", { exact: true })).toBeVisible();
  await expect(page.getByText(validScriptHashHex, { exact: true })).toBeVisible();
  await expect(page.getByText(validScriptHashBech32, { exact: true })).toBeVisible();
});

test("scripts page authors native scripts from JSON", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Scripts Hash native scripts/ }).click();
  await expect(page.getByRole("heading", { name: "Native Scripts" })).toBeVisible();

  await page.getByRole("button", { name: "JSON" }).click();
  await page
    .getByPlaceholder('{"all":["addr_vkh1...",{"active_from":120}]}')
    .fill(validScriptJson);

  await expect(page.getByText("Signature", { exact: true })).toBeVisible();
  await expect(page.getByText(validScriptJson, { exact: true })).toBeVisible();
  await expect(page.getByText(validScriptCborHex, { exact: true })).toBeVisible();
  await expect(page.getByText(validScriptHashHex, { exact: true })).toBeVisible();
});

test("scripts page shows validation warnings for awkward scripts", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Scripts Hash native scripts/ }).click();
  await expect(page.getByRole("heading", { name: "Native Scripts" })).toBeVisible();

  await page.getByPlaceholder("8200581c...").fill(warningScriptCborHex);

  await expect(page.getByText("Any", { exact: true })).toBeVisible();
  await expect(page.getByText("warning", { exact: true })).toBeVisible();
  await expect(page.getByText(warningScriptHashHex, { exact: true })).toBeVisible();
  await expect(
    page.getByText("Script contains redundant timelock constraints."),
  ).toBeVisible();
});
