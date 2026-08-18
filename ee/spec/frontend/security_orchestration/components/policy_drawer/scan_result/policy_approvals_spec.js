import { mount } from '@vue/test-utils';
import { GlLink } from '@gitlab/ui';
import PolicyApprovals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';
import { createApprovers } from '../../../mocks/mock_scan_result_policy_data';

describe('PolicyApprovals component', () => {
  let wrapper;

  const factory = (propsData) => {
    wrapper = mount(PolicyApprovals, { propsData });
  };

  const findApprovers = () => wrapper.findAll('[data-testid]');
  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findSeparator = () => wrapper.find('.action-separator');

  describe.each`
    approvalsRequired | approvers                                                         | expectedTestIds                                                                                   | expectedApprovalText | expectedApproverText
    ${1}              | ${createApprovers({ group: true })}                               | ${[['data-testid', 'gid://gitlab/Group/2']]}                                                      | ${'approval'}        | ${/grouppath2/}
    ${3}              | ${createApprovers({ group: true })}                               | ${[['data-testid', 'gid://gitlab/Group/2']]}                                                      | ${'approvals'}       | ${/grouppath2/}
    ${1}              | ${createApprovers({ group: true, user: true })}                   | ${[['data-testid', 'gid://gitlab/Group/2'], ['data-testid', 'gid://gitlab/User/1']]}              | ${'approval'}        | ${/grouppath2[^]*and[^]*username1/}
    ${1}              | ${createApprovers({ group: true, role: true, customRole: true })} | ${[['data-testid', 'gid://gitlab/Group/2'], ['data-testid', 'Owner'], ['data-testid', 'Custom']]} | ${'approval'}        | ${/grouppath2[^]*Owner[^]*and[^]*Custom[^]/}
  `(
    'with $approvalsRequired approval required and $approvers.length approvers',
    ({
      approvalsRequired,
      approvers,
      expectedApprovalText,
      expectedApproverText,
      expectedTestIds,
    }) => {
      beforeEach(() => {
        const action = { approvals_required: approvalsRequired };
        factory({ action, approvers });
      });

      it('renders the complete text', () => {
        const text = wrapper.text();

        expect(text).toContain(expectedApprovalText);
        expect(text).toMatch(expectedApproverText);
      });

      it('includes popover related info to all links', () => {
        const expectedClasses = ['gl-link', 'gfm', 'gfm-project_member', 'js-user-link'];

        findLinks().wrappers.forEach((link) => {
          expect(link.classes()).toStrictEqual(expect.arrayContaining(expectedClasses));
        });
      });

      it('renders separator for all approvers', () => {
        expect(findSeparator().exists()).toBe(true);
      });

      it('renders link with proper attributes for all approvers', () => {
        findApprovers().wrappers.forEach((link, index) => {
          const expectedAttribute = expectedTestIds[index][0];
          const expectedValue = expectedTestIds[index][1];
          expect(link.attributes(expectedAttribute)).toBe(expectedValue);
        });
      });
    },
  );

  describe('not last item text', () => {
    it('does not render last item text if it is not a last item', () => {
      factory({ action: { approvals_required: 1 }, approvers: createApprovers({ group: true }) });

      expect(wrapper.text()).toContain('approval');
      expect(wrapper.text()).not.toContain('if any of the following occur:');
    });
  });

  describe('zero approvers', () => {
    it('shows no approval text', () => {
      factory({ approvers: [] });
      expect(wrapper.text()).toBe('Requires no approvals if any of the following occur:');
      expect(findSeparator().exists()).toBe(false);
    });
  });

  describe('last item', () => {
    it('does not render separator for last item', () => {
      const action = { approvals_required: 1 };
      factory({
        action,
        approvers: createApprovers({ group: true, user: true, role: true }),
        isLastItem: true,
      });

      expect(findSeparator().exists()).toBe(false);
    });
  });

  describe('warn mode', () => {
    it('shows the correct text', () => {
      factory({
        action: { approvals_required: 0 },
        approvers: createApprovers({ group: true, user: true, role: true }),
        isWarnMode: true,
      });
      const text = wrapper.text();
      expect(text).toContain(
        'Warn users with a bot comment and require users to either dismiss the policy or obtain',
      );
      expect(text).toContain('grouppath2,');
      expect(text).toContain('username1 and');
      expect(text).toContain('Owner');
    });
  });
});
