// To run this spec locally first run `bundle exec rake gitlab:js:routes`

import { sharedPathHelperTests } from 'jest/lib/utils/path_helpers/shared';

const testCases = [
  {
    pathHelperName: 'editGroupSettingsRolesAndPermissionPath',
    args: ['foo/bar', 1],
    baseExpected: '/groups/foo/bar/-/settings/roles_and_permissions/1/edit',
  },
  {
    pathHelperName: 'groupSettingsWorkItemsPath',
    args: [
      'foo/bar',
      { search: 'foo bar', page: '1', format: 'json', anchor: 'js-visibility-settings' },
    ],
    baseExpected:
      '/groups/foo/bar/-/settings/work_items.json?search=foo%20bar&page=1#js-visibility-settings',
  },
];

sharedPathHelperTests({ pathHelpersFilePath: 'ee/lib/utils/path_helpers/group', testCases });
