// To run this spec locally first run `bundle exec rake gitlab:js:routes`

import { sharedPathHelperTests } from 'jest/lib/utils/path_helpers/shared';

const testCases = [
  {
    pathHelperName: 'projectQualityTestCasePath',
    args: ['foo/bar/baz', 1],
    baseExpected: '/foo/bar/baz/-/quality/test_cases/1',
  },
  {
    pathHelperName: 'projectQualityTestCasePath',
    args: ['baz', 1],
    baseExpected: '/baz/-/quality/test_cases/1',
  },
  {
    pathHelperName: 'projectQualityTestCasePath',
    args: ['/baz', 1],
    baseExpected: '/baz/-/quality/test_cases/1',
  },
  {
    pathHelperName: 'projectQualityTestCasePath',
    args: [
      '/baz',
      1,
      { search: 'foo bar', page: '1', format: 'json', anchor: 'js-visibility-settings' },
    ],
    baseExpected: '/baz/-/quality/test_cases/1.json?search=foo%20bar&page=1#js-visibility-settings',
  },
];

sharedPathHelperTests({ pathHelpersFilePath: 'ee/lib/utils/path_helpers/project', testCases });

describe('when shorthand project path helper is not provided the projectFullPath argument', () => {
  it('throws an error', async () => {
    const { projectQualityTestCasePath } = await import('ee/lib/utils/path_helpers/project');

    expect(() => {
      projectQualityTestCasePath();
    }).toThrow(new Error('Route missing required keys: projectFullPath'));
  });
});

describe('when shorthand project path helper is not provided the projectFullPath argument as a string', () => {
  it('throws an error', async () => {
    const { projectQualityTestCasePath } = await import('ee/lib/utils/path_helpers/project');

    expect(() => {
      projectQualityTestCasePath({ projectFullPath: '/foo/bar/baz' });
    }).toThrow(new Error('projectFullPath must be a string'));
  });
});
