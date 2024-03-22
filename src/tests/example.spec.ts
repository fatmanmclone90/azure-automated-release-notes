import { expect } from '@playwright/test';
import { test } from '../fixtures/fixtures';

test('has title', async ({ page, setTestId }) => {
  setTestId(1)
  await page.goto('https://playwright.dev/');

  // Expect a title "to contain" a substring.
  await expect(page).toHaveTitle(/foo/);
});

test('get started link', async ({ page, setTestId }) => {
  setTestId(2)
  
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
