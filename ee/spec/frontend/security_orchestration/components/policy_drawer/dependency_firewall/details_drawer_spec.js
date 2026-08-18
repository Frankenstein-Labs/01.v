import DependencyFirewallDrawer from 'ee/security_orchestration/components/policy_drawer/dependency_firewall/details_drawer.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import DenyAllowViewList from 'ee/security_orchestration/components/policy_drawer/scan_result/deny_allow_view_list.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER } from 'ee/security_orchestration/components/constants';
import {
  mockEnforcedDfwPolicy,
  mockAdvisoryDfwPolicy,
  mockAllowedDfwPolicy,
  mockEmptyRulesDfwPolicy,
  mockWithExceptionsDfwPolicy,
  mockMultipleRulesDfwPolicy,
} from 'ee_jest/security_orchestration/mocks/mock_dependency_firewall_policy_data';

describe('DependencyFirewallDrawer', () => {
  let wrapper;

  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findEnforcementType = () => wrapper.findByTestId('enforcement-type');
  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findRulesSubheader = () => wrapper.findByTestId('rules-subheader');
  const findNoRulesMessage = () => wrapper.findByTestId('no-rules-message');
  const findRules = () => wrapper.findAllByTestId('rule');
  const findDenyAllowViewLists = () => wrapper.findAllComponents(DenyAllowViewList);

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(DependencyFirewallDrawer, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
    });
  };

  describe('with invalid or missing yaml', () => {
    it('renders the layout without throwing', () => {
      createComponent({ propsData: { policy: {} } });

      expect(findPolicyDrawerLayout().exists()).toBe(true);
      expect(findPolicyDrawerLayout().props()).toMatchObject({
        description: '',
        type: DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER,
      });
    });

    it('does not render rules or subheader', () => {
      createComponent({ propsData: { policy: {} } });

      expect(findRulesSubheader().exists()).toBe(false);
      expect(findRules()).toHaveLength(0);
    });

    it('does not render the summary section for malformed YAML', () => {
      createComponent({ propsData: { policy: { yaml: 'invalid: yaml: :' } } });

      expect(findSummary().exists()).toBe(false);
    });
  });

  describe('enforcement_type: enforced', () => {
    beforeEach(() => {
      createComponent({ propsData: { policy: mockEnforcedDfwPolicy } });
    });

    it('renders the policy drawer layout with correct type', () => {
      expect(findPolicyDrawerLayout().props()).toMatchObject({
        policy: mockEnforcedDfwPolicy,
        type: DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER,
      });
    });

    it('renders "Enforced" as the enforcement type label', () => {
      expect(findEnforcementType().text()).toContain('Enforced');
    });

    it('renders the rules subheader', () => {
      expect(findRulesSubheader().text()).toBe(
        'This policy applies when the license for a dependency matches any of the following criteria:',
      );
    });

    it('renders a DenyAllowViewList with isDenied=true and the license items', () => {
      const lists = findDenyAllowViewLists();

      expect(lists).toHaveLength(1);
      expect(lists.at(0).props('isDenied')).toBe(true);
      expect(lists.at(0).props('items')).toMatchObject([
        { license: { text: 'GPL-3.0' }, exceptions: [] },
        { license: { text: 'AGPL-3.0' }, exceptions: [] },
      ]);
    });

    it('passes the description to the layout', () => {
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'Block packages with copyleft licenses',
      );
    });
  });

  describe('enforcement_type: warn', () => {
    beforeEach(() => {
      createComponent({ propsData: { policy: mockAdvisoryDfwPolicy } });
    });

    it('renders "Advisory" as the enforcement type label', () => {
      expect(findEnforcementType().text()).toContain('Advisory');
    });

    it('renders a DenyAllowViewList with the denied license', () => {
      const lists = findDenyAllowViewLists();

      expect(lists).toHaveLength(1);
      expect(lists.at(0).props('isDenied')).toBe(true);
      expect(lists.at(0).props('items')).toMatchObject([
        { license: { text: 'Apache-2.0' }, exceptions: [] },
      ]);
    });
  });

  describe('allowed licenses rule', () => {
    beforeEach(() => {
      createComponent({ propsData: { policy: mockAllowedDfwPolicy } });
    });

    it('does not render the enforcement type row when enforcement_type is absent', () => {
      expect(findEnforcementType().exists()).toBe(false);
    });

    it('renders a DenyAllowViewList with isDenied=false', () => {
      const lists = findDenyAllowViewLists();

      expect(lists).toHaveLength(1);
      expect(lists.at(0).props('isDenied')).toBe(false);
    });

    it('passes allowed license names as items', () => {
      expect(findDenyAllowViewLists().at(0).props('items')).toMatchObject([
        { license: { text: 'MIT' }, exceptions: [] },
      ]);
    });

    it('does not render a deny list', () => {
      expect(findDenyAllowViewLists().at(0).props('isDenied')).toBe(false);
    });
  });

  describe('rule with exceptions', () => {
    beforeEach(() => {
      createComponent({ propsData: { policy: mockWithExceptionsDfwPolicy } });
    });

    it('passes exception purls to each license item', () => {
      const items = findDenyAllowViewLists().at(0).props('items');

      expect(items).toHaveLength(1);
      expect(items[0].exceptions).toEqual([
        'pkg:npm/known-gpl-package@1.0.0',
        'pkg:npm/another-exception@2.0.0',
      ]);
    });

    it('associates the same exceptions with every license in the rule', () => {
      const items = findDenyAllowViewLists().at(0).props('items');

      items.forEach((item) => {
        expect(item.exceptions).toHaveLength(2);
      });
    });
  });

  describe('multiple rules', () => {
    beforeEach(() => {
      createComponent({ propsData: { policy: mockMultipleRulesDfwPolicy } });
    });

    it('renders one DenyAllowViewList per rule', () => {
      expect(findDenyAllowViewLists()).toHaveLength(2);
    });

    it('renders the first rule as a deny list', () => {
      expect(findDenyAllowViewLists().at(0).props('isDenied')).toBe(true);
    });

    it('renders the second rule as an allow list', () => {
      expect(findDenyAllowViewLists().at(1).props('isDenied')).toBe(false);
    });

    it('passes the correct items to each rule', () => {
      const lists = findDenyAllowViewLists();

      expect(lists.at(0).props('items')).toMatchObject([{ license: { text: 'GPL-3.0' } }]);
      expect(lists.at(1).props('items')).toMatchObject([
        { license: { text: 'MIT' } },
        { license: { text: 'Apache-2.0' } },
      ]);
    });
  });

  describe('empty rules array', () => {
    beforeEach(() => {
      createComponent({ propsData: { policy: mockEmptyRulesDfwPolicy } });
    });

    it('shows the no-rules fallback message', () => {
      expect(findNoRulesMessage().exists()).toBe(true);
    });

    it('does not render any rule items', () => {
      expect(findRules()).toHaveLength(0);
    });

    it('does not render the rules subheader', () => {
      expect(findRulesSubheader().exists()).toBe(false);
    });
  });

  describe('summary section', () => {
    it('renders the summary info row', () => {
      createComponent({ propsData: { policy: mockEnforcedDfwPolicy } });

      expect(findSummary().exists()).toBe(true);
    });
  });
});
