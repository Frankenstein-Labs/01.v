import {
  showRolesFetchError,
  createNewCustomRoleOption,
  createNewAdminRoleOption,
} from 'ee/roles_and_permissions/components/roles_crud/utils';
import { createAlert } from '~/alert';

jest.mock('~/alert');

describe('showRolesFetchError', () => {
  it('shows alert', () => {
    showRolesFetchError();

    expect(createAlert).toHaveBeenCalledTimes(1);
    expect(createAlert).toHaveBeenCalledWith({
      message: 'Failed to fetch roles.',
      dismissible: false,
    });
  });
});

describe('createNewCustomRoleOption', () => {
  it('returns new custom role option', () => {
    expect(createNewCustomRoleOption('new/role/path')).toEqual({
      text: 'Member role',
      href: 'new/role/path',
      description: 'Create a role to manage member permissions for groups and projects.',
    });
  });
});

describe('createNewAdminRoleOption', () => {
  it('returns new admin role option', () => {
    expect(createNewAdminRoleOption('new/role/path')).toEqual({
      text: 'Admin role',
      href: 'new/role/path?admin',
      description: 'Create a role to manage permissions in the Admin area.',
    });
  });
});
