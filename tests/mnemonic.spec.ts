import { expect, test } from "@playwright/test";

test("restore page generates mnemonics and keeps phrase hidden by default", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: /Restore Choose family first/ }).click();
  await expect(page.locator(".page-title")).toHaveText("Restore And Build");

  await page.getByRole("button", { name: "12 words" }).click();
  await page.getByRole("button", { name: "Generate phrase" }).click();

  await expect(page.getByRole("button", { name: "Copy phrase" })).toBeVisible();
  await expect(
    page.getByText("Phrase hidden. 12 words are available for clipboard copy."),
  ).toBeVisible();
  await expect(page.locator(".mnemonic-word")).toHaveCount(0);

  await page.getByRole("button", { name: "Show phrase" }).click();
  await expect(page.locator(".mnemonic-word")).toHaveCount(12);
});
