import { expect, test } from "@playwright/test";

const scriptCborHex =
  "008200581c3207c32d806ec2cabc78ff7ed869bd3098b7db93c43cc8aa93ab59eb";
const scriptHashHex =
  "558ba956d2a19cecd37cb49d3f0ddff1985013dd86e695128bc3d996";
const scriptHashBech32 =
  "script12k96j4kj5xwwe5mukjwn7rwl7xv9qy7asmnf2y5tc0vevku89av";

test("scripts page hashes native script CBOR", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Scripts Hash native scripts/ }).click();
  await expect(page.getByRole("heading", { name: "Native Scripts" })).toBeVisible();

  await page.getByPlaceholder("8200581c...").fill(scriptCborHex);

  await expect(page.getByText(scriptHashHex)).toBeVisible();
  await expect(page.getByText(scriptHashBech32)).toBeVisible();
});
