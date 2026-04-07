import { expect, test } from "@playwright/test";

test("mnemonic page respects privacy mode", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Mnemonic Generate recovery phrases/ }).click();
  await expect(page.locator(".page-title")).toHaveText("Mnemonic Generation");

  await page.getByRole("button", { name: "12 words" }).click();
  await page.getByRole("button", { name: "Generate phrase" }).click();

  await expect(page.getByRole("button", { name: "Copy phrase" })).toBeVisible();
  await expect(
    page.getByText("Phrase hidden. 12 words are available for clipboard copy."),
  ).toBeVisible();
  await expect(page.locator(".mnemonic-word")).toHaveCount(0);

  await page.getByRole("button", { name: "Visible" }).click();
  await expect(page.locator(".mnemonic-word")).toHaveCount(12);
});
