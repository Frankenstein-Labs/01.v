import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import {
  GlButton,
  GlDisclosureDropdown,
  GlEmptyState,
  GlLoadingIcon,
  GlSearchBoxByType,
  GlTabs,
} from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import PoliciesList from 'ee/security_policies/components/list/policies_list.vue';
import StatsBar from 'ee/security_policies/components/list/stats_bar.vue';
import BundlesList from 'ee/security_policies/components/list/bundles_list.vue';
import updatePolicyMutation from 'ee/security_orchestration/graphql/mutations/create_policy.mutation.graphql';
import projectSecurityPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_security_policies.query.graphql';

const POLICY_WITH_YAML = {
  name: 'Scan policy',
  type: 'scan_result',
  enabled: true,
  updatedAt: '2024-01-01',
  yaml: 'name: Scan policy\nenabled: true\nrules:\n- type: scan_finding\n  scanners:\n  - sast\nactions:\n- type: require_approval\n  approvals_required: 1\n',
};

const mockPolicies = [
  POLICY_WITH_YAML,
  {
    name: 'Vulnerability severity rule',
    type: 'scan_result',
    enabled: true,
    updatedAt: '2024-01-02',
    yaml: '',
  },
  {
    name: 'Secret push protection',
    type: 'scan_execution',
    enabled: false,
    updatedAt: '2024-01-03',
    yaml: '',
  },
];

Vue.use(VueApollo);

describe('PoliciesList', () => {
  let wrapper;
  let mutationHandler;

  const policiesQueryResponse = (policies) => ({
    data: {
      namespace: {
        __typename: 'Project',
        id: 'gid://gitlab/Project/1',
        securityPolicies: {
          __typename: 'SecurityPolicyConnection',
          nodes: policies.map((policy, index) => ({
            __typename: 'SecurityPolicy',
            id: `gid://gitlab/Security::Policy/${index + 1}`,
            policyConfigurationId: 'gid://gitlab/Security::OrchestrationPolicyConfiguration/1',
            csp: false,
            editPath: '',
            policyScope: null,
            testRuns: { __typename: 'PolicyTestRunConnection', nodes: [] },
            policyAttributes: null,
            ...policy,
          })),
          pageInfo: {
            __typename: 'PageInfo',
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  });

  const createComponent = async ({ loading = false, policies = mockPolicies } = {}) => {
    mutationHandler = jest.fn().mockResolvedValue({
      data: {
        scanExecutionPolicyCommit: {
          __typename: 'ScanExecutionPolicyCommitPayload',
          branch: 'main',
          validationErrors: null,
          errors: [],
        },
      },
    });

    const queryHandler = loading
      ? jest.fn().mockReturnValue(new Promise(() => {}))
      : jest.fn().mockResolvedValue(policiesQueryResponse(policies));

    wrapper = shallowMount(PoliciesList, {
      provide: {
        namespacePath: 'group/project',
        namespaceType: 'project',
      },
      apolloProvider: createMockApollo([
        [projectSecurityPoliciesQuery, queryHandler],
        [updatePolicyMutation, mutationHandler],
      ]),
    });

    if (!loading) {
      await waitForPromises();
    }
  };

  const findNewPolicyButton = () =>
    wrapper.findAllComponents(GlButton).wrappers.find((w) => w.attributes('variant') === 'confirm');
  const findStatsBar = () => wrapper.findComponent(StatsBar);
  const findPolicyRows = () => wrapper.findAll('[data-testid="policy-row"]');
  const findExpansionPanel = () => wrapper.find('[data-testid="policy-expansion-panel"]');
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findSearch = () => wrapper.findComponent(GlSearchBoxByType);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findBundlesList = () => wrapper.findComponent(BundlesList);

  it('renders "Policies" heading', async () => {
    await createComponent();

    expect(wrapper.find('h1').text()).toBe('Policies');
  });

  it('renders tabs for Policies and Bundles', async () => {
    await createComponent();

    expect(findTabs().exists()).toBe(true);
  });

  it('renders StatsBar', async () => {
    await createComponent();

    expect(findStatsBar().exists()).toBe(true);
  });

  it('renders BundlesList in the bundles tab', async () => {
    await createComponent();

    expect(findBundlesList().exists()).toBe(true);
  });

  it('renders search box', async () => {
    await createComponent();

    expect(findSearch().exists()).toBe(true);
  });

  it('shows loading icon while fetching and hides policy rows', async () => {
    await createComponent({ loading: true });

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findPolicyRows()).toHaveLength(0);
  });

  it('renders one row per policy', async () => {
    await createComponent();

    expect(findPolicyRows()).toHaveLength(mockPolicies.length);
  });

  it('emits create when confirm button is clicked', async () => {
    await createComponent();

    findNewPolicyButton().vm.$emit('click');

    expect(wrapper.emitted('create')).toBeDefined();
  });

  it('filters policies by search query', async () => {
    await createComponent();

    const allCount = findPolicyRows().length;
    await findSearch().vm.$emit('input', 'Vulnerability');
    await nextTick();

    expect(findPolicyRows().length).toBeLessThan(allCount);
    expect(findPolicyRows()).toHaveLength(1);
  });

  it('shows empty state when search has no results', async () => {
    await createComponent();

    await findSearch().vm.$emit('input', 'zzznomatches');
    await nextTick();

    expect(findPolicyRows()).toHaveLength(0);
    expect(findEmptyState().exists()).toBe(true);
  });

  it('does not show empty state when policies exist', async () => {
    await createComponent();

    expect(findEmptyState().exists()).toBe(false);
  });

  it('shows empty state when no policies exist', async () => {
    await createComponent({ policies: [] });

    expect(findEmptyState().exists()).toBe(true);
    expect(findPolicyRows()).toHaveLength(0);
  });

  describe('row expansion', () => {
    it('expansion panel is hidden by default', async () => {
      await createComponent();

      expect(findExpansionPanel().exists()).toBe(false);
    });

    it('clicking a row shows the expansion panel', async () => {
      await createComponent();

      await findPolicyRows().at(0).trigger('click');

      expect(findExpansionPanel().exists()).toBe(true);
    });

    it('clicking an expanded row collapses it', async () => {
      await createComponent();

      await findPolicyRows().at(0).trigger('click');
      await findPolicyRows().at(0).trigger('click');

      expect(findExpansionPanel().exists()).toBe(false);
    });

    it('shows rules and actions parsed from policy YAML', async () => {
      await createComponent();

      await findPolicyRows().at(0).trigger('click');

      const panel = findExpansionPanel();
      expect(panel.text()).toContain('Scan Finding');
      expect(panel.text()).toContain('Require Approval');
    });

    it('emits edit when Edit button in expansion panel is clicked', async () => {
      await createComponent();

      await findPolicyRows().at(0).trigger('click');

      const editButton = findExpansionPanel()
        .findAllComponents(GlButton)
        .wrappers.find((b) => b.text() === 'Edit');
      await editButton.vm.$emit('click');

      expect(wrapper.emitted('edit')).toBeDefined();
      expect(wrapper.emitted('edit')[0][0].name).toBe(POLICY_WITH_YAML.name);
    });
  });

  describe('row menu', () => {
    it('edit menu item emits edit with the policy', async () => {
      await createComponent();

      const dropdown = wrapper.findAllComponents(GlDisclosureDropdown).at(0);
      const editItem = dropdown.props('items')[0];

      editItem.action();

      expect(wrapper.emitted('edit')).toBeDefined();
      expect(wrapper.emitted('edit')[0][0].name).toBe(mockPolicies[0].name);
    });

    it('delete menu item calls deletePolicy', async () => {
      await createComponent();

      const dropdown = wrapper.findAllComponents(GlDisclosureDropdown).at(0);
      const deleteItem = dropdown.props('items').find((item) => item.text === 'Delete');

      await deleteItem.action();

      expect(mutationHandler).toHaveBeenCalledWith(expect.objectContaining({ mode: 'REMOVE' }));
    });
  });
});
