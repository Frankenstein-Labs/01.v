import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PolicyDetails from 'ee/approvals/components/security_orchestration/policy_details.vue';
import PolicyApprovals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';

describe('PolicyDetails', () => {
  let wrapper;

  const initialPolicy = {
    name: 'test policy approval',
    editPath: `/policy/path/-/security/policies/test policy approval/edit?type=scan_result_policy`,
    isSelected: true,
    rules: [
      {
        type: 'scan_finding',
        branches: [],
        scanners: [],
        vulnerabilities_allowed: 0,
        severity_levels: ['critical'],
        vulnerability_states: ['newly_detected'],
      },
    ],
    actions: [
      { type: 'require_approval', approvals_required: 1, user_approvers: ['admin'] },
      { type: 'require_approval', approvals_required: 1, user_approvers: ['admin'] },
    ],
    actionApprovers: [
      { users: [{ id: 1, name: 'username' }], allGroups: [] },
      { users: [{ id: 2, name: 'username2' }], allGroups: [] },
    ],
    source: {
      project: {
        fullPath: 'policy/path',
      },
    },
  };

  const factory = (policyData = {}) => {
    wrapper = shallowMount(PolicyDetails, {
      propsData: {
        policy: {
          ...initialPolicy,
          ...policyData,
        },
      },
    });
  };

  const findEditPolicy = () => wrapper.findComponent(GlButton);
  const findPolicyApprovals = () => wrapper.findComponent(PolicyApprovals);
  const findAllPolicyApprovals = () => wrapper.findAllComponents(PolicyApprovals);

  describe('with isSelected set to true', () => {
    beforeEach(() => {
      factory();
    });

    it('renders the text version of the related action and each of the rules', () => {
      const text = wrapper.text();
      expect(findPolicyApprovals().exists()).toBe(true);
      expect(findAllPolicyApprovals()).toHaveLength(2);
      expect(findAllPolicyApprovals().at(0).props('approvers')).toEqual([
        { id: 1, name: 'username' },
      ]);
      expect(findAllPolicyApprovals().at(1).props('approvers')).toEqual([
        { id: 2, name: 'username2' },
      ]);
      expect(text).toContain('When any security scanner');
      expect(text).toContain('critical');
    });

    it('renders a link to policy path', () => {
      expect(findEditPolicy().exists()).toBe(true);
      expect(findEditPolicy().attributes('href')).toBe(initialPolicy.editPath);
    });

    describe('with an inherited policy', () => {
      beforeEach(() => {
        factory({ source: { inherited: true, namespace: { fullPath: 'policy/path' } } });
      });

      it('renders a link to policy path', () => {
        expect(findEditPolicy().exists()).toBe(true);
        expect(findEditPolicy().attributes('href')).toBe(initialPolicy.editPath);
      });
    });
  });

  describe('with isSelected set to false', () => {
    beforeEach(() => {
      factory({ isSelected: false });
    });

    it('does not render a text based on action and rules', () => {
      expect(wrapper.text()).toBe('');
      expect(findPolicyApprovals().exists()).toBe(false);
    });

    it('does not render a link to the policy path', () => {
      expect(findEditPolicy().exists()).toBe(false);
    });
  });

  describe('policy without namesapce', () => {
    it.each`
      namespace                                 | linkVisible
      ${{ namespace: { name: 'policy-name' } }} | ${true}
      ${{ namespace: undefined }}               | ${false}
    `('should hide link for policy without namespace', ({ namespace, linkVisible }) => {
      factory({
        source: {
          inherited: true,
          ...namespace,
        },
      });

      expect(findEditPolicy().exists()).toBe(linkVisible);
    });
  });
});
