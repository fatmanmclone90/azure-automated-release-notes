import { test, expect } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto('https://playwright.dev/');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/Playwright/);
});

test('get started link', async ({ page }) => {
  
  await test.step("Given the user is on the Playwright page", async () => {
    await page.goto('https://playwright.dev/');
  })

  await test.step("When they click the Get Started link", async () => {
    // Click the get started link.
    await page.getByRole('link', { name: 'Get started' }).click();
  })

  await test.step("Then they see the Installation page", async () => {
    // Expects page to have a heading with the name of Installation.
    await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible();
  })
});
