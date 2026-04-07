import { expect, test } from "@playwright/test";

const mnemonic =
  "message mask aunt wheel ten maze between tomato slow analyst ladder such report capital produce";
const firstAddressPublicKey =
  "addr_xvk1gs3fqwhyayz2drdx857yw7jyvnjqsje2sc7qlx4ryp8z4cpvh4hn4tnjeqqtultplcgwp067389dy5fafmnqtreus6tju0ueyrjnynq0l3lh3";
const secondAddressPublicKey =
  "addr_xvk1lz7rn3xtrxuk9gn38gzpd9rjpknlu9758z70hkl9wu79hc7xqw7fxu57u5r4xcyjrxl7q0j9533zv2mnsqhzmkpxw50lqmcdn7f5m7s943403";

test("derivation page is reactive and hides values in private mode", async ({
  page,
}) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Derivation Follow CIP-1852/ }).click();
  await expect(page.getByRole("heading", { name: "Key Derivation" })).toBeVisible();

  const mnemonicInput = page.locator(
    'input[type="password"][placeholder="abandon abandon ... or use the generated phrase"]',
  );
  await mnemonicInput.fill(mnemonic);

  await expect(
    page.getByText("Value hidden in private mode. Use Copy to move it to the clipboard.").first(),
  ).toBeVisible();
  await expect(page.getByText(firstAddressPublicKey)).toHaveCount(0);

  await page.getByRole("button", { name: "Visible" }).click();
  await expect(page.getByText(firstAddressPublicKey)).toBeVisible();

  await page.getByRole("spinbutton", { name: "Address index" }).fill("1");
  await expect(page.getByText(secondAddressPublicKey)).toBeVisible();
  await expect(page.getByText(firstAddressPublicKey)).toHaveCount(0);
});
