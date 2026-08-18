import MockAdapter from 'axios-mock-adapter';
import { cloneDeep } from 'lodash-es';
import {
  getMemberRole,
  getRoleDropdownItems,
  ldapRole,
} from 'ee/members/components/table/drawer/utils';
import { callRoleUpdateApi } from '~/members/components/table/drawer/utils';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import { roleDropdownItems } from 'ee/members/utils';
import { upgradedMember, ldapMember } from '../../../mock_data';

describe('Role details drawer utils', () => {
  describe('getRoleDropdownItems', () => {
    it('returns dropdown items', () => {
      const roles = getRoleDropdownItems(upgradedMember);
      const expectedRoles = roleDropdownItems(upgradedMember);

      expect(roles).toEqual(expectedRoles);
    });

    it('returns LDAP role for LDAP users', () => {
      const roles = getRoleDropdownItems(ldapMember);

      expect(roles.flatten).toContain(ldapRole);
      expect(roles.formatted).toContainEqual({ text: 'LDAP', options: [ldapRole] });
    });
  });

  describe('getMemberRole', () => {
    const roles = getRoleDropdownItems(upgradedMember).flatten;

    it.each(roles)('returns $text role for member', (expectedRole) => {
      const member = cloneDeep(upgradedMember);
      member.accessLevel.integerValue = expectedRole.accessLevel;
      member.accessLevel.memberRoleId = expectedRole.memberRoleId;
      const role = getMemberRole(roles, member);

      expect(role).toBe(expectedRole);
    });

    it('returns LDAP role for LDAP users that are synced to the LDAP settings', () => {
      const role = getMemberRole(roles, ldapMember);

      expect(role).toBe(ldapRole);
    });

    it('returns actual role for LDAP users that have had their role overridden', () => {
      const member = { ...ldapMember, isOverridden: true };
      const role = getMemberRole(roles, member);

      expect(role.text).toBe('custom role 1');
    });
  });

  describe('callRoleUpdateApi', () => {
    it.each`
      namespace  | propertyName
      ${'user'}  | ${'access_level'}
      ${'group'} | ${'group_access'}
    `(
      'calls update API with expected data for $namespace namespace',
      async ({ namespace, propertyName }) => {
        const memberPath = 'member/path/123';
        const member = { ...upgradedMember, memberPath, namespace };

        const mockAxios = new MockAdapter(axios);
        mockAxios.onPut(memberPath).replyOnce(HTTP_STATUS_OK);

        const customRole = roleDropdownItems(upgradedMember).flatten.find(
          (role) => role.memberRoleId === upgradedMember.accessLevel.memberRoleId,
        );

        await callRoleUpdateApi(member, customRole);

        expect(mockAxios.history.put).toHaveLength(1);
        expect(mockAxios.history.put[0].data).toBe(
          JSON.stringify({ [propertyName]: 10, member_role_id: customRole.memberRoleId }),
        );
      },
    );
  });
});
