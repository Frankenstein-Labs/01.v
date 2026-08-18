import { GlAlert, GlSprintf, GlButton, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleDetails from 'ee/roles_and_permissions/components/role_details/role_details.vue';
import RoleDetailsContent from 'ee/roles_and_permissions/components/role_details/role_details_content.vue';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import { BASE_ROLES_WITHOUT_MINIMAL_ACCESS } from '~/access_level/constants';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { visitUrl } from '~/lib/utils/url_utility';
import createMockApollo from 'helpers/mock_apollo_helper';
import memberRoleQuery from 'ee/roles_and_permissions/graphql/role_details/member_role.query.graphql';
import adminRoleQuery from 'ee/roles_and_permissions/graphql/admin_role/role.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import DeleteRoleTooltipWrapper from 'ee/roles_and_permissions/components/delete_role_tooltip_wrapper.vue';
import {
  mockMemberRole,
  getMemberRoleQueryResponse,
  mockMemberRoleWithUsers,
  mockMemberRoleWithSecurityPolicies,
  mockAdminRoleWithLdapLinks,
} from '../../mock_data';

Vue.use(VueApollo);

jest.mock('~/lib/utils/url_utility');

const getMemberRoleHandler = (memberRole) =>
  jest.fn().mockResolvedValue(getMemberRoleQueryResponse(memberRole));
const defaultMemberRoleHandler = getMemberRoleHandler(mockMemberRole);

describe('Role details', () => {
  let wrapper;

  const createWrapper = ({
    roleId = '5',
    roleQuery = memberRoleQuery,
    memberRoleHandler = defaultMemberRoleHandler,
    listPagePath = '/list/page/path',
    isAdminRole = false,
  } = {}) => {
    wrapper = shallowMountExtended(RoleDetails, {
      apolloProvider: createMockApollo([[roleQuery, memberRoleHandler]]),
      propsData: { roleId, listPagePath, isAdminRole },
      stubs: { GlSprintf },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
    });

    return waitForPromises();
  };

  const findRoleDetails = () => wrapper.findByTestId('role-details');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findDetailsContent = () => wrapper.findComponent(RoleDetailsContent);
  const findEditButton = () => wrapper.findComponentByTestId('edit-button');
  const findDeleteRoleModal = () => wrapper.findComponent(DeleteRoleModal);
  const getTooltip = (findFn) => getBinding(findFn().element, 'gl-tooltip');
  const findDeleteRoleTooltipWrapper = () => wrapper.findComponent(DeleteRoleTooltipWrapper);
  const findDeleteButton = () => findDeleteRoleTooltipWrapper().findComponent(GlButton);

  describe('when there is a query error', () => {
    beforeEach(() => createWrapper({ memberRoleHandler: jest.fn().mockRejectedValue('test') }));

    it('shows error alert', () => {
      const alert = wrapper.findComponent(GlAlert);

      expect(alert.text()).toBe('Failed to fetch role.');
      expect(alert.props()).toMatchObject({ variant: 'danger', dismissible: false });
    });

    it('does not show role details', () => {
      expect(findRoleDetails().exists()).toBe(false);
    });
  });

  describe('for all roles', () => {
    beforeEach(() => createWrapper());

    it('shows role details content', () => {
      expect(findDetailsContent().props('role')).toEqual(mockMemberRole);
    });
  });

  describe('when the role is a standard role', () => {
    describe.each(BASE_ROLES_WITHOUT_MINIMAL_ACCESS)('$text', (role) => {
      beforeEach(() => createWrapper({ roleId: role.value }));

      it('does not call query', () => {
        expect(defaultMemberRoleHandler).not.toHaveBeenCalled();
      });

      it('shows role name', () => {
        expect(findPageHeading().props('heading')).toBe(role.text);
      });

      it('does not show action buttons', () => {
        expect(findEditButton().exists()).toBe(false);
        expect(findDeleteRoleTooltipWrapper().exists()).toBe(false);
      });

      it('shows header description', () => {
        expect(findPageHeading().text()).toBe(
          'This role is available by default and cannot be changed.',
        );
      });
    });
  });

  describe('when the role is a custom role', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('calls query', () => {
      expect(defaultMemberRoleHandler).toHaveBeenCalledTimes(1);
      expect(defaultMemberRoleHandler).toHaveBeenCalledWith({ id: 'gid://gitlab/MemberRole/5' });
    });

    it('shows loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    describe('after query is done', () => {
      beforeEach(waitForPromises);

      it('shows role name', () => {
        expect(findPageHeading().props('heading')).toBe('Custom role');
      });

      it('shows action buttons', () => {
        expect(findEditButton().exists()).toBe(true);
        expect(findDeleteButton().exists()).toBe(true);
      });

      it('shows header description', () => {
        expect(findPageHeading().text()).toBe('Custom role created on Aug 4, 2024');
      });
    });
  });

  describe('when the role is an admin role', () => {
    beforeEach(() => createWrapper({ isAdminRole: true, roleQuery: adminRoleQuery }));

    it('calls admin role query', () => {
      expect(defaultMemberRoleHandler).toHaveBeenCalledTimes(1);
      expect(defaultMemberRoleHandler).toHaveBeenCalledWith({ id: 'gid://gitlab/MemberRole/5' });
    });
  });

  describe('edit button', () => {
    beforeEach(() => createWrapper());

    it('shows button', () => {
      expect(findEditButton().attributes('href')).toBe('role/path/1/edit?from_details');
      expect(findEditButton().props('icon')).toBe('pencil');
    });

    it('shows button tooltip', () => {
      expect(getTooltip(findEditButton).value).toBe('Edit role');
    });
  });

  describe('delete button', () => {
    beforeEach(() => createWrapper());

    it('shows delete role tooltip wrapper', () => {
      expect(findDeleteRoleTooltipWrapper().props('role')).toEqual(mockMemberRole);
    });

    it('shows button', () => {
      expect(findDeleteButton().props()).toMatchObject({
        icon: 'remove',
        category: 'secondary',
        variant: 'danger',
        disabled: false,
      });
    });

    it('shows button tooltip', () => {
      expect(getTooltip(findDeleteButton).value).toBe('Delete role');
    });
  });

  it.each`
    role                                  | roleQuery          | description
    ${mockMemberRoleWithUsers}            | ${memberRoleQuery} | ${'users'}
    ${mockMemberRoleWithSecurityPolicies} | ${memberRoleQuery} | ${'dependent security policies'}
    ${mockAdminRoleWithLdapLinks}         | ${adminRoleQuery}  | ${'dependent admin role ldap syncs'}
  `('disables delete button when role has $description', async ({ role, roleQuery }) => {
    await createWrapper({
      roleQuery,
      memberRoleHandler: getMemberRoleHandler(role),
      isAdminRole: roleQuery === adminRoleQuery,
    });

    expect(findDeleteButton().props('disabled')).toBe(true);
  });

  describe('delete role modal', () => {
    beforeEach(() => createWrapper());

    it('shows modal', () => {
      expect(findDeleteRoleModal().props('role')).toBe(null);
    });

    describe('when delete button is clicked', () => {
      beforeEach(() => {
        findDeleteButton().vm.$emit('click');
        return nextTick();
      });

      it('passes role to modal', () => {
        expect(findDeleteRoleModal().props('role')).toEqual(mockMemberRole);
      });

      it('clears role to delete when modal is closed', async () => {
        findDeleteRoleModal().vm.$emit('close');
        await nextTick();

        expect(findDeleteRoleModal().props('role')).toBe(null);
      });

      describe('when role is deleted', () => {
        beforeEach(() => {
          findDeleteRoleModal().vm.$emit('deleted');
          return nextTick();
        });

        it('navigates to list page', () => {
          expect(visitUrl).toHaveBeenCalledWith('/list/page/path');
        });

        it('keeps the modal open', () => {
          expect(findDeleteRoleModal().props('role')).toEqual(mockMemberRole);
        });
      });
    });
  });
});
