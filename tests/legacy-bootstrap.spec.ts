import { expect, test } from "@playwright/test";

const icarusAddressXPub =
  "addr_xvk12q8m3slawygjfu4kejfkpmkhxwtqnhh6h422d9rvn4y5duqck6uugzq73gcwwz6rm558t4ze48unnalalxzcj23tjand8fr83lnllss86krr5";
const icarusExpectedAddress =
  "Ae2tdPwUPEZKdwAH18yuA45Fa5pdhm638CpF8MrG6999cMiwdzEWetEFJBk";

const byronAddressXPub =
  "addr_xvk154775y260zd4yu90gw8k74muunmr39dlvztzs5p3cvnk0smpvehs23stg9uxz3zdpu0ex5gxpugj5cjad4m8knlnzprzk40nwl8felc420xwu";
const byronRootXPub =
  "root_xvk1rcntpytsyd3q9qfdfdyl6ud2ea5qurxg9q6ns5w07lu2j7299kl8j0tmc5phyqqgwu2dgw95nu549gkuq05l800h7prtuuj7gr5umvc7gfagw";
const byronExpectedAddress =
  "2w1sdSJu3GVidw5zyVHtVm3XTzpV8w68W8XLnWybAXYYZzD1iY2ET21Etah5unPjYbUnr1VqEr5bkF1N8SaV4Ec9pxnPHLVXD5Q";

test("legacy page constructs Icarus and Byron bootstrap addresses", async ({
  page,
}) => {
  await page.goto("/");

  await expect(page.getByRole("heading", { name: "Project Overview" })).toBeVisible();
  await page.getByRole("button", { name: /Legacy Build bootstrap addresses/ }).click();
  await expect(
    page.getByRole("heading", { name: "Legacy Construction" }),
  ).toBeVisible();

  const addressXPubArea = page.getByPlaceholder("addr_xvk1...");
  await addressXPubArea.fill(icarusAddressXPub);
  await expect(page.getByText(icarusExpectedAddress)).toBeVisible();

  await page.getByRole("button", { name: "Byron" }).click();
  await page.getByPlaceholder("root_xvk1...").fill(byronRootXPub);
  await page.getByPlaceholder("0H/0").fill("0H/0");
  await addressXPubArea.fill(byronAddressXPub);
  await expect(page.getByText(byronExpectedAddress)).toBeVisible();
});
