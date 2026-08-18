import { getExpectedFilterTokenConfigs } from 'jest/admin/users/mock_data';
import AdminRoleToken from 'ee/admin/users/components/admin_role_token.vue';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';

export { STANDARD_TOKEN_CONFIGS } from 'jest/admin/users/mock_data';

export const FILTER_TOKEN_CONFIGS = getExpectedFilterTokenConfigs([
  { value: 'admins', title: 'Administrator' },
  { value: 'auditors', title: 'Auditor' },
  { value: 'external', title: 'External' },
]);

export const ADMIN_ROLE_TOKEN = {
  title: 'Custom admin role',
  type: 'admin_role_id',
  token: AdminRoleToken,
  operators: OPERATORS_IS,
  unique: true,
};
