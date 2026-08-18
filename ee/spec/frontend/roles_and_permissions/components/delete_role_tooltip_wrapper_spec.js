import { GlPopover, GlLink } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import DeleteRoleTooltipWrapper from 'ee/roles_and_permissions/components/delete_role_tooltip_wrapper.vue';
import {
  mockAdminRoleWithLdapLinks,
  mockMemberRole,
  mockMemberRoleWithUsers,
  mockMemberRoleWithSecurityPolicies,
  mockAdminRoleWithUsers,
} from '../mock_data';

describe('Delete role tooltip wrapper', () => {
  let wrapper;

  const createWrapper = ({
    role = mockMemberRole,
    containerId = 'container-id',
    slotContent = '',
  } = {}) => {
    wrapper = mountExtended(DeleteRoleTooltipWrapper, {
      propsData: { role, containerId },
      directives: { GlTooltip: createMockDirective('gl-tooltip') },
      slots: { default: slotContent },
    });
  };

  const findWrapperDiv = () => wrapper.find('div');
  const findTooltip = () => getBinding(findWrapperDiv().element, 'gl-tooltip');
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findPolicyItems = () => wrapper.find('ul').findAll('li');
  const findPolicyLinkAt = (index) => findPolicyItems().at(index).findComponent(GlLink);

  it('renders slot content', () => {
    createWrapper({ slotContent: 'slot content' });

    expect(findWrapperDiv().text()).toBe('slot content');
  });

  describe('when the role can be deleted', () => {
    beforeEach(() => createWrapper({ role: mockMemberRole }));

    it('does not show tooltip', () => {
      expect(findTooltip().value).toBe('');
    });

    it('does not show popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe.each`
    description                              | role                          | expectedText
    ${'custom role has assigned users'}      | ${mockMemberRoleWithUsers}    | ${'To delete custom member role, remove role from all group and project members.'}
    ${'admin role has assigned users'}       | ${mockAdminRoleWithUsers}     | ${'To delete custom admin role, remove role from all users.'}
    ${'admin role has dependent LDAP syncs'} | ${mockAdminRoleWithLdapLinks} | ${"You can't delete this admin custom role until you delete all LDAP syncs that use it."}
  `('when the $description', ({ role, expectedText }) => {
    beforeEach(() => createWrapper({ role }));

    it('shows tooltip', () => {
      expect(findTooltip()).toMatchObject({
        value: expectedText,
        modifiers: { d0: true, left: true, viewport: true },
      });
    });

    it('does not show popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe('when the role has dependent security policies', () => {
    beforeEach(() => createWrapper({ role: mockMemberRoleWithSecurityPolicies }));

    it('does not show tooltip', () => {
      expect(findTooltip().value).toBe('');
    });

    describe('popover', () => {
      it('shows popover', () => {
        expect(findPopover().props('target')()).toBe(findWrapperDiv().element);
        expect(findPopover().props()).toMatchObject({
          title: 'Security policy dependency',
          placement: 'left',
          boundary: 'viewport',
          container: 'container-id',
        });
      });

      it('shows body text', () => {
        expect(findPopover().text()).toContain(
          'To delete custom member role, remove role from the following security policies:',
        );
      });

      it('shows correct number of policy links', () => {
        expect(findPolicyItems()).toHaveLength(2);
      });

      it.each`
        index | name          | href
        ${0}  | ${'policy 1'} | ${'path/1'}
        ${1}  | ${'policy 2'} | ${'path/2'}
      `('shows policy link to $name', ({ index, name, href }) => {
        expect(findPolicyLinkAt(index).text()).toBe(name);
        expect(findPolicyLinkAt(index).props()).toMatchObject({ href, target: '_blank' });
      });
    });
  });
});
