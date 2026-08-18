import { isCustomRole, isAdminRole, isRoleInUse } from 'ee/roles_and_permissions/utils';
import {
  standardRoles,
  memberRoles,
  adminRoles,
  mockMemberRole,
  mockMemberRoleWithUsers,
  mockMemberRoleWithSecurityPolicies,
  mockAdminRoleWithLdapLinks,
} from './mock_data';

describe('Roles and permissions utils', () => {
  describe('isCustomRole', () => {
    describe.each(standardRoles)('for standard role $name', (role) => {
      it('returns false', () => {
        expect(isCustomRole(role)).toBe(false);
      });
    });

    describe.each(memberRoles)('for custom role $name', (role) => {
      it('returns true', () => {
        expect(isCustomRole(role)).toBe(true);
      });
    });

    describe.each(adminRoles)('for admin role $name', (role) => {
      it('returns true', () => {
        expect(isAdminRole(role)).toBe(true);
      });
    });
  });

  describe('isRoleInUse', () => {
    it('returns false when role is not in use', () => {
      expect(isRoleInUse(mockMemberRole)).toBe(false);
    });

    it.each`
      role                                  | description
      ${mockMemberRoleWithUsers}            | ${'users'}
      ${mockMemberRoleWithSecurityPolicies} | ${'dependent security policies'}
      ${mockAdminRoleWithLdapLinks}         | ${'dependent admin role ldap syncs'}
    `('returns true when role has $description', ({ role }) => {
      expect(isRoleInUse(role)).toBe(true);
    });
  });
});
