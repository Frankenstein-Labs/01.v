import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import getClusterAgentsQuery from 'ee/security_dashboard/graphql/queries/cluster_agents.query.graphql';
import ClusterToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/cluster_token.vue';
import SearchSuggestion from 'ee/security_dashboard/components/shared/filtered_search/components/search_suggestion.vue';
import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { projectClusters } from 'ee_jest/security_dashboard/components/mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('Cluster Token component', () => {
  let wrapper;
  const projectFullPath = 'test/path';
  const defaultProjectClustersQueryResolver = jest.fn().mockResolvedValue(projectClusters);

  const mockConfig = {
    multiSelect: true,
    unique: true,
    operators: OPERATORS_OR,
  };

  const createWrapper = ({
    value = {},
    active = false,
    stubs,
    projectClustersQueryResolver = defaultProjectClustersQueryResolver,
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(ClusterToken, {
      apolloProvider: createMockApollo([[getClusterAgentsQuery, projectClustersQueryResolver]]),
      propsData: {
        config: mockConfig,
        value,
        active,
      },
      provide: {
        portalName: 'fake target',
        alignSuggestions: jest.fn(),
        termsAsTokens: () => false,
        projectFullPath,
      },
      stubs: {
        SearchSuggestion,
        ...stubs,
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);
  const isOptionChecked = (v) =>
    wrapper.findComponentByTestId(`suggestion-${v}`).props('selected') === true;

  const clickDropdownItem = async (...ids) => {
    await Promise.all(
      ids.map((id) => {
        findFilteredSearchToken().vm.$emit('select', id);
        return nextTick();
      }),
    );

    findFilteredSearchToken().vm.$emit('complete');
    await nextTick();
  };

  describe('default view', () => {
    const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

    beforeEach(() => {
      createWrapper();
    });

    it('shows the label', () => {
      expect(findFilteredSearchToken().props('value')).toEqual({ data: ['ALL'] });
      expect(wrapper.findByTestId('cluster-token-placeholder').text()).toBe('All clusters');
    });

    it('shows the dropdown with correct options', async () => {
      await waitForPromises();

      const findDropdownOptions = () =>
        wrapper.findAllComponents(SearchSuggestion).wrappers.map((c) => c.text());

      expect(findDropdownOptions()).toEqual([
        'All clusters',
        'primary-agent',
        'james-bond-agent',
        'jason-bourne-agent',
      ]);
    });

    it('shows the loading icon when cluster agents are not yet loaded', async () => {
      expect(findLoadingIcon().exists()).toBe(true);

      await waitForPromises();

      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('transforms filters correclty', () => {
      expect(
        ClusterToken.transformFilters([
          { value: 'test-agent-1', gid: 'gid://GitLab/Agent/4' },
          { value: 'test-agent-2', gid: 'gid://GitLab/Agent/5' },
        ]),
      ).toEqual({ clusterAgentId: ['gid://GitLab/Agent/4', 'gid://GitLab/Agent/5'] });
    });

    it('transforms query parameters correclty', () => {
      expect(
        ClusterToken.transformQueryParams([
          { value: 'test-agent-1', gid: 'gid://GitLab/Agent/4' },
          { value: 'test-agent-2', gid: 'gid://GitLab/Agent/5' },
        ]),
      ).toEqual('test-agent-1,test-agent-2');

      expect(ClusterToken.transformQueryParams([])).toBe('ALL');
    });
  });

  it('shows an alert on a failed GraphQL request', async () => {
    createWrapper({ projectClustersQueryResolver: jest.fn().mockRejectedValue() });
    await waitForPromises();

    expect(createAlert).toHaveBeenCalledWith({ message: 'Failed to load cluster agents.' });
  });

  describe('item selection', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('toggles the item selection when clicked on', async () => {
      await clickDropdownItem('primary-agent', 'james-bond-agent');

      expect(isOptionChecked('primary-agent')).toBe(true);
      expect(isOptionChecked('james-bond-agent')).toBe(true);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(false);
    });

    it('selects only "All clusters" when that item is selected', async () => {
      await clickDropdownItem('primary-agent', 'ALL');

      expect(isOptionChecked('primary-agent')).toBe(false);
      expect(isOptionChecked('james-bond-agent')).toBe(false);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(true);
    });

    it('selects "All clusters" when last selected item is deselected', async () => {
      // Select and deselect "primary-agent"
      await clickDropdownItem('primary-agent', 'primary-agent');

      expect(isOptionChecked('primary-agent')).toBe(false);
      expect(isOptionChecked('james-bond-agent')).toBe(false);
      expect(isOptionChecked('jason-bourne-agent')).toBe(false);
      expect(isOptionChecked('ALL')).toBe(true);
    });
  });

  describe('toggle text', () => {
    const findSlotView = () => wrapper.findAllByTestId('filtered-search-token-segment').at(2);

    beforeEach(() => {
      createWrapper({ mountFn: mountExtended });
    });

    it('shows "primary-agent, james-bond-agent" when primary-agent, james-bond-agent are selected', async () => {
      await clickDropdownItem('primary-agent', 'james-bond-agent');
      expect(findSlotView().text()).toBe('primary-agent, james-bond-agent');
    });

    it('shows "primary-agent, james-bond-agent +1 more" when primary-agent, james-bond-agent, and jason-bourne-agent are selected', async () => {
      await clickDropdownItem('primary-agent', 'james-bond-agent', 'jason-bourne-agent');
      expect(findSlotView().text()).toBe('primary-agent, james-bond-agent +1 more');
    });

    it('shows "primary-agent" when only primary-agent is selected', async () => {
      await clickDropdownItem('primary-agent');
      expect(findSlotView().text()).toBe('primary-agent');
    });
  });
});
