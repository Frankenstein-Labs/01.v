import {
  generateBadges,
  canDisableTwoFactor,
  canOverride,
  canUnban,
  roleDropdownItems,
  initialSelectedRole,
  handleMemberRoleUpdate,
} from 'ee/members/utils';
import { member as memberMock, directMember, inheritedMember } from 'jest/members/mock_data';
import showGlobalToast from '~/vue_shared/plugins/global_toast';
import { customRoles } from './mock_data';

jest.mock('~/vue_shared/plugins/global_toast');
jest.mock('~/members/utils', () => ({
  ...jest.requireActual('~/members/utils'),
  roleDropdownItems: jest.fn().mockReturnValue({ flatten: [] }),
}));
const CEUtils = jest.requireMock('~/members/utils');

describe('Members Utils', () => {
  describe('generateBadges', () => {
    it('has correct properties for each badge', () => {
      const badges = generateBadges({
        member: memberMock,
        isCurrentUser: true,
        canManageMembers: true,
      });

      badges.forEach((badge) => {
        expect(badge).toEqual(
          expect.objectContaining({
            show: expect.any(Boolean),
            text: expect.any(String),
            variant: expect.stringMatching(/neutral|info|success|danger|warning/),
          }),
        );
      });
    });

    it.each`
      member                                                        | expected
      ${{ ...memberMock, usingLicense: true }}                      | ${{ show: true, text: 'Is using seat', variant: 'neutral' }}
      ${{ ...memberMock, groupSso: true }}                          | ${{ show: true, text: 'SAML', variant: 'info' }}
      ${{ ...memberMock, groupManagedAccount: true }}               | ${{ show: true, text: 'Managed Account', variant: 'info' }}
      ${{ ...memberMock, canOverride: true }}                       | ${{ show: true, text: 'LDAP', variant: 'info' }}
      ${{ ...memberMock, enterpriseUserOfThisGroup: true }}         | ${{ show: true, text: 'Enterprise', variant: 'info' }}
      ${{ ...memberMock, ...{ user: { isServiceAccount: true } } }} | ${{ show: true, text: 'Service Account', variant: 'neutral' }}
    `('returns expected output for "$expected.text" badge', ({ member, expected }) => {
      expect(
        generateBadges({ member, isCurrentUser: true, canManageMembers: true }),
      ).toContainEqual(expect.objectContaining(expected));
    });
  });

  describe('canDisableTwoFactor', () => {
    it.each`
      member                                           | expected
      ${{ ...memberMock, canDisableTwoFactor: true }}  | ${true}
      ${{ ...memberMock, canDisableTwoFactor: false }} | ${false}
    `(
      'returns $expected for members whose two factor authentication can be disabled',
      ({ member, expected }) => {
        expect(canDisableTwoFactor(member)).toBe(expected);
      },
    );
  });

  describe('canOverride', () => {
    it.each`
      member                                        | expected
      ${{ ...directMember, canOverride: true }}     | ${true}
      ${{ ...inheritedMember, canOverride: true }}  | ${false}
      ${{ ...directMember, canOverride: false }}    | ${false}
      ${{ ...inheritedMember, canOverride: false }} | ${false}
    `('returns $expected', ({ member, expected }) => {
      expect(canOverride(member)).toBe(expected);
    });
  });

  describe('canUnban', () => {
    it.each`
      member                                               | expected
      ${{ ...memberMock, banned: true, canUnban: true }}   | ${true}
      ${{ ...memberMock, banned: true, canUnban: false }}  | ${false}
      ${{ ...memberMock, banned: false, canUnban: true }}  | ${false}
      ${{ ...memberMock, banned: false, canUnban: false }} | ${false}
    `(
      'returns $expected for "member banned $member.banned and member canUnban $member.canUnban"',
      ({ member, expected }) => {
        expect(canUnban(member)).toBe(expected);
      },
    );
  });

  describe('roleDropdownItems', () => {
    describe('without custom roles', () => {
      it('returns CE version of the dropdowns', () => {
        const { flatten } = roleDropdownItems(memberMock);

        expect(flatten).toEqual([]);
      });
    });

    describe('with custom roles', () => {
      it('returns properly flatten dropdowns', () => {
        const { flatten } = roleDropdownItems({ ...memberMock, customRoles });
        expect(flatten).toHaveLength(2);

        customRoles.forEach((role) => {
          expect(flatten).toContainEqual({
            text: role.name,
            value: `role-custom-${role.memberRoleId}`,
            description: role.description,
            accessLevel: role.baseAccessLevel,
            memberRoleId: role.memberRoleId,
            permissions: role.permissions,
          });
        });
      });

      it('returns properly formatted dropdowns', () => {
        const { formatted } = roleDropdownItems({ ...memberMock, customRoles });

        expect(formatted).toHaveLength(2);
        expect(formatted[0].text).toBe('Default roles');
        expect(formatted[0].options).toHaveLength(0);
        expect(formatted[1].text).toBe('Custom roles');
        expect(formatted[1].options).toHaveLength(2);
      });
    });
  });

  describe('initialSelectedRole', () => {
    it('find and return correct value', () => {
      const role = { accessLevel: 10, memberRoleId: 9, text: 'Guest', value: 'role-custom-0' };
      const initialRole = initialSelectedRole([role], {
        accessLevel: { integerValue: 10, memberRoleId: 9 },
      });

      expect(initialRole).toBe(role);
    });
  });

  describe('handleMemberRoleUpdate', () => {
    const update = {
      currentRole: 'guest',
      requestedRole: 'dev',
      response: { data: { enqueued: true } },
    };

    describe('enqueueing role change', () => {
      it('shows a toast', () => {
        handleMemberRoleUpdate(update);
        expect(showGlobalToast).toHaveBeenCalledWith(
          'Role change request was sent to the administrator.',
        );
      });

      it('returns current user role', () => {
        const role = handleMemberRoleUpdate(update);
        expect(role).toBe(update.currentRole);
      });
    });

    it('calls CE as a fallback for immediate role change', () => {
      const immediateUpdate = { ...update, response: {} };
      jest.spyOn(CEUtils, 'handleMemberRoleUpdate');
      handleMemberRoleUpdate(immediateUpdate);
      expect(CEUtils.handleMemberRoleUpdate).toHaveBeenCalledWith(immediateUpdate);
    });
  });
});
