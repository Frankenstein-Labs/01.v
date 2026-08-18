import { GlLink, GlCollapsibleListbox, GlSkeletonLoader } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';
import { helpPagePath } from '~/helpers/help_page_helper';
import App from 'ee/dependency_firewall/components/app.vue';
import groupRuleActivityQuery from 'ee/dependency_firewall/graphql/queries/group_dependency_firewall_rule_activity.query.graphql';
import projectRuleActivityQuery from 'ee/dependency_firewall/graphql/queries/project_dependency_firewall_rule_activity.query.graphql';

Vue.use(VueApollo);

const GROUP_PATH = 'gitlab-org';

const mockRules = [
  {
    id: 'gid://gitlab/Security::DependencyFirewallPolicyRule/1',
    ruleType: 'LICENSE',
    policyName: 'Block GPL',
    mode: 'ENFORCE',
    enabled: true,
    activityCount: 12,
    lastModified: {
      at: '2020-07-06T00:00:00Z',
      by: { id: 'gid://gitlab/User/1', name: 'Jane Doe' },
    },
    __typename: 'DependencyFirewallRuleActivity',
  },
  {
    id: 'gid://gitlab/Security::DependencyFirewallPolicyRule/2',
    ruleType: 'VULNERABILITY',
    policyName: 'Warn on vulns',
    mode: 'WARN',
    enabled: true,
    activityCount: 3,
    lastModified: { at: '2020-07-06T00:00:00Z', by: null },
    __typename: 'DependencyFirewallRuleActivity',
  },
];

const mockSummary = {
  blocked: 21,
  warned: 14,
  totalTriggers: 500,
  activeRules: 4,
  blockingRules: 2,
  warningRules: 2,
  __typename: 'DependencyFirewallActivitySummary',
};

const buildResponse = (nodes = mockRules, summary = mockSummary, typename = 'Group') => ({
  data: {
    dependencyFirewall: {
      id: `gid://gitlab/${typename}/1`,
      dependencyFirewallActivitySummary: summary,
      dependencyFirewallRuleActivity: nodes,
      __typename: typename,
    },
  },
});

describe('DependencyFirewallDashboardApp', () => {
  useFakeDate(2020, 6, 10); // 2020-07-10

  let wrapper;

  const createComponent = ({ handler, namespaceType = 'group' } = {}) => {
    const isProject = namespaceType === 'project';
    const query = isProject ? projectRuleActivityQuery : groupRuleActivityQuery;
    const requestHandler =
      handler ||
      jest
        .fn()
        .mockResolvedValue(buildResponse(mockRules, mockSummary, isProject ? 'Project' : 'Group'));
    wrapper = mountExtended(App, {
      apolloProvider: createMockApollo([[query, requestHandler]]),
      propsData: { fullPath: GROUP_PATH, namespaceType },
    });
  };

  const findTable = () => wrapper.findComponentByTestId('dependency-firewall-rules-table');
  const findRows = () => findTable().findAll('tbody tr');
  const findBlockedTotal = () => wrapper.findByTestId('blocked-total');
  const findWarnedTotal = () => wrapper.findByTestId('warned-total');
  const findTotalTriggers = () => wrapper.findByTestId('total-triggers');
  const findActiveRulesTotal = () => wrapper.findByTestId('active-rules-total');

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findBanner = () => wrapper.findComponentByTestId('ga-billing-alert');
  const findErrorAlert = () => wrapper.findByTestId('error-alert');
  const findTimeWindowListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  it('shows skeleton loaders while the query is in flight', () => {
    createComponent();

    expect(findSkeletonLoader().exists()).toBe(true);
  });

  describe('once loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('hides the skeleton loaders', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('shows the group supply-chain subtitle', () => {
      expect(wrapper.text()).toContain("entering your group's supply chain");
    });

    it('shows server-side totals and active-rule counts from the summary', () => {
      expect(findBlockedTotal().text()).toBe('21');
      expect(findWarnedTotal().text()).toBe('14');
      expect(findTotalTriggers().text()).toBe('500');
      expect(findActiveRulesTotal().text()).toBe('4');
    });

    it('renders one table row per rule', () => {
      expect(findRows()).toHaveLength(2);
      expect(findTable().text()).toContain('Block GPL');
      expect(findTable().text()).toContain('Warn on vulns');
    });

    it('renders a friendly label for the rule type instead of the raw value', () => {
      expect(findTable().text()).toContain('License compliance rule');
      expect(findTable().text()).toContain('Vulnerability severity rule');
      expect(findTable().text()).not.toContain('LICENSE');
    });

    it('renders the last modified time per rule, with the editing user when present', () => {
      expect(wrapper.findAllComponents(TimeAgoTooltip)).toHaveLength(2);
      expect(wrapper.findAllComponents(TimeAgoTooltip).at(0).props('time')).toBe(
        mockRules[0].lastModified.at,
      );
      // row 0 has an author, row 1 does not
      expect(findTable().text()).toContain('By Jane Doe');
    });
  });

  describe('at project level', () => {
    beforeEach(async () => {
      createComponent({ namespaceType: 'project' });
      await waitForPromises();
    });

    it('shows the project supply-chain subtitle', () => {
      expect(wrapper.text()).toContain("entering your project's supply chain");
    });

    it('renders the rules returned by the project-level query', () => {
      expect(findRows()).toHaveLength(2);
      expect(findTable().text()).toContain('Block GPL');
      expect(findBlockedTotal().text()).toBe('21');
    });
  });

  it('shows an enabled or disabled status per rule', async () => {
    const disabledRule = { ...mockRules[1], policyName: 'Disabled policy', enabled: false };
    createComponent({
      handler: jest.fn().mockResolvedValue(buildResponse([mockRules[0], disabledRule])),
    });
    await waitForPromises();

    expect(findTable().text()).toContain('Enabled');
    expect(findTable().text()).toContain('Disabled');
  });

  it('shows a generic label instead of the raw value for an unrecognized rule type', async () => {
    const unknownRule = { ...mockRules[0], policyName: 'Mystery policy', ruleType: 'PACKAGE_NAME' };
    createComponent({ handler: jest.fn().mockResolvedValue(buildResponse([unknownRule])) });
    await waitForPromises();

    expect(findTable().text()).toContain('Unknown policy type');
    expect(findTable().text()).not.toContain('PACKAGE_NAME');
  });

  it('renders the empty state when there is no activity', async () => {
    createComponent({ handler: jest.fn().mockResolvedValue(buildResponse([])) });
    await waitForPromises();

    expect(findTable().text()).toContain('No active dependency firewall rules');
  });

  it('shows an error alert when the query fails', async () => {
    createComponent({ handler: jest.fn().mockRejectedValue(new Error('boom')) });
    await waitForPromises();

    expect(findErrorAlert().exists()).toBe(true);
  });

  it('clears the error alert after a window change triggers a successful refetch', async () => {
    const handler = jest
      .fn()
      .mockRejectedValueOnce(new Error('boom'))
      .mockResolvedValue(buildResponse());
    createComponent({ handler });
    await waitForPromises();

    expect(findErrorAlert().exists()).toBe(true);

    findTimeWindowListbox().vm.$emit('select', 30);
    await waitForPromises();

    expect(findErrorAlert().exists()).toBe(false);
  });

  describe('GitLab credits banner', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a non-dismissible warning banner about credits at GA', () => {
      expect(findBanner().props('variant')).toBe('warning');
      expect(findBanner().props('dismissible')).toBe(false);
      expect(findBanner().props('title')).toBe('Charges may be incurred at the end of beta');
      expect(findBanner().text()).toContain('free during the beta period');
      expect(findBanner().findComponent(GlLink).text()).toBe('GitLab Credits');
    });

    it('links to the GitLab credits documentation', () => {
      expect(findBanner().findComponent(GlLink).attributes('href')).toBe(
        helpPagePath('subscriptions/gitlab_credits'),
      );
    });
  });

  describe('time window', () => {
    it('labels the dropdown with a screen-reader-only "Time period" label', () => {
      createComponent();

      const labelledBy = findTimeWindowListbox().props('toggleAriaLabelledBy');
      const label = wrapper.find(`#${labelledBy}`);

      expect(label.classes()).toContain('gl-sr-only');
      expect(label.text()).toBe('Time period');
    });

    it('defaults to the last 7 days when querying', () => {
      const handler = jest.fn().mockResolvedValue(buildResponse());
      createComponent({ handler });

      expect(handler).toHaveBeenCalledWith({
        fullPath: GROUP_PATH,
        from: '2020-07-04',
      });
    });

    it.each`
      value | label             | from
      ${7}  | ${'Last 7 days'}  | ${'2020-07-04'}
      ${30} | ${'Last 30 days'} | ${'2020-06-11'}
    `('refetches with $from when "$label" is selected', async ({ value, from }) => {
      const handler = jest.fn().mockResolvedValue(buildResponse());
      createComponent({ handler });
      await waitForPromises();

      findTimeWindowListbox().vm.$emit('select', value);
      await waitForPromises();

      expect(handler).toHaveBeenLastCalledWith({
        fullPath: GROUP_PATH,
        from,
      });
    });

    it('shows fresh activity counts when returning to a previously selected window', async () => {
      const ruleWithCount = (activityCount) => [{ ...mockRules[0], activityCount }];
      const handler = jest
        .fn()
        .mockImplementation(({ from }) =>
          Promise.resolve(buildResponse(ruleWithCount(from === '2020-07-04' ? 111 : 999))),
        );
      createComponent({ handler });
      await waitForPromises();

      findTimeWindowListbox().vm.$emit('select', 30);
      await waitForPromises();
      findTimeWindowListbox().vm.$emit('select', 7);
      await waitForPromises();

      expect(findTable().text()).toContain('111');
      expect(findTable().text()).not.toContain('999');
    });
  });
});
