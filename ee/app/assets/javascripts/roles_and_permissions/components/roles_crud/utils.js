import { createAlert } from '~/alert';
import { s__ } from '~/locale';

export const showRolesFetchError = () => {
  createAlert({ message: s__('MemberRole|Failed to fetch roles.'), dismissible: false });
};

export const createNewCustomRoleOption = (href) => ({
  text: s__('MemberRole|Member role'),
  href,
  description: s__(
    'MemberRole|Create a role to manage member permissions for groups and projects.',
  ),
});

export const createNewAdminRoleOption = (href) => ({
  text: s__('MemberRole|Admin role'),
  href: `${href}?admin`,
  description: s__('MemberRole|Create a role to manage permissions in the Admin area.'),
});
