import { test as base } from '@playwright/test';

type MyFixtures = {
  setTestId: (ids: number) => void;
};

export const test = base.extend<MyFixtures>({
  setTestId: async ({ }, use, testInfo) => {
    const callback = (id: number) => {
        testInfo.annotations.push({
            type: 'testId',
            description: id.toString(),
        });
    };

    await use(callback);
  }
});