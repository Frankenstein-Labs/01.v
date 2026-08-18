import { s__ } from '~/locale';
import { createTokenConfig } from '~/admin/users/constants';
import AdminRoleToken from './components/admin_role_token.vue';

export {
  getFilterTokenConfigs,
  SOLO_OWNED_ORGANIZATIONS_EMPTY,
  I18N_USER_ACTIONS,
  SOLO_OWNED_ORGANIZATIONS_REQUESTED_COUNT,
} from '~/admin/users/constants';

export const ACCESS_LEVEL_OPTIONS = [
  { value: 'admins', title: s__('AdminUsers|Administrator') },
  { value: 'auditors', title: s__('AdminUsers|Auditor') },
  { value: 'external', title: s__('AdminUsers|External') },
];

// NOTE: If you add a config, also add the querystring key to app/helpers/sorting_helper.rb.
// Otherwise, changing the sort will remove the querystring for the config.
export const getStandardTokenConfigs = ({ customRoles, readAdminRole }) => {
  const configs = [];
  // Add the admin role token config if the license allows custom roles (Ultimate-only feature)
  // and the user has permission to read custom admin roles.
  if (customRoles && readAdminRole) {
    configs.push(
      createTokenConfig({
        type: 'admin_role_id',
        title: s__('MemberRole|Custom admin role'),
        token: AdminRoleToken,
      }),
    );
  }

  return configs;
};
