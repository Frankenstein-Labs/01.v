import { helpPagePath } from '~/helpers/help_page_helper';

export const PRIVATE_PROFILES_DISABLED_ICON = 'private-profiles-disabled-icon';
export const PRIVATE_PROFILES_DISABLED_HELP_LINK = helpPagePath(
  'administration/settings/account_and_limit_settings',
  { anchor: 'set-profiles-of-new-users-to-private-by-default' },
);
