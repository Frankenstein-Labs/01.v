import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';

import AgentFlowList from 'ee/ai/duo_agents_platform/components/common/agent_flow_list.vue';
import AgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import NoCreditsBanner from 'ee/ai/duo_agents_platform/components/common/no_credits_banner.vue';
import UsageBillingForbiddenBanner from 'ee/ai/duo_agents_platform/components/common/usage_billing_forbidden_banner.vue';

import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import getFlowTypesQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_flow_types.query.graphql';
import { mockAgentFlowsResponse } from '../../../mocks';

Vue.use(VueApollo);

const mockFlowTypesNodes = [
  { id: '1', name: 'Code review', foundationalFlowReference: 'code_review/v1' },
  { id: '2', name: 'Convert to gitlab ci', foundationalFlowReference: 'convert_to_gitlab_ci' },
  { id: '3', name: 'Developer', foundationalFlowReference: 'developer/v1' },
  { id: '4', name: 'Fix pipeline', foundationalFlowReference: 'fix_pipeline/v1' },
  { id: '5', name: 'Issue to merge request', foundationalFlowReference: 'issue_to_merge_request' },
  { id: '6', name: 'Software development', foundationalFlowReference: 'software_development' },
];

const mockFlowTypesResponse = {
  data: {
    aiCatalogItems: {
      nodes: mockFlowTypesNodes,
    },
  },
};

const mockFlowTypesQueryHandler = jest.fn().mockResolvedValue(mockFlowTypesResponse);

const mockEmptyFlowTypesHandler = jest.fn().mockResolvedValue({
  data: { aiCatalogItems: { nodes: [] } },
});

const mockFlowTypesErrorHandler = jest
  .fn()
  .mockRejectedValue(new Error('Failed to fetch flow types'));

describe('AgentsPlatformIndex', () => {
  let wrapper;

  const defaultProps = {
    initialSort: 'UPDATED_DESC',
    hasInitialWorkflows: true,
    isLoadingWorkflows: false,
    workflows: mockAgentFlowsResponse.data.project.duoWorkflowWorkflows.edges.map(
      (edge) => edge.node,
    ),
    workflowsPageInfo: { startCursor: 'asdf', endCursor: 'asdf' },
  };

  const createWrapper = ({
    props = {},
    provide = {},
    apolloHandlers = [[getFlowTypesQuery, mockFlowTypesQueryHandler]],
  } = {}) => {
    const apolloProvider = createMockApollo([...apolloHandlers]);

    wrapper = shallowMountExtended(AgentsPlatformIndex, {
      apolloProvider,
      propsData: { ...defaultProps, ...props },
      provide: {
        isSidePanelView: false,
        creditsAvailable: true,
        ...provide,
      },
    });

    return waitForPromises();
  };

  const findWorkflowsList = () => wrapper.findComponent(AgentFlowList);
  const findLoadingIcon = () => wrapper.findByTestId('loading-container');
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findFilteredSearchBar = () => wrapper.findComponent(FilteredSearchBar);
  const findNoCreditsBanner = () => wrapper.findComponent(NoCreditsBanner);
  const findUsageBillingForbiddenBanner = () => wrapper.findComponent(UsageBillingForbiddenBanner);
  const findTimeRangeDropdown = () => wrapper.findComponentByTestId('time-range-filter');

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('when not in side panel view', () => {
    beforeEach(() => {
      createWrapper({ provide: { isSidePanelView: false } });
    });

    it('loads the page heading', () => {
      expect(findPageHeading().props('heading')).toBe('Sessions');
    });
  });

  describe('when in side panel view', () => {
    beforeEach(() => {
      createWrapper({ provide: { isSidePanelView: true } });
    });

    it('does not render the page heading', () => {
      expect(findPageHeading().exists()).toBe(false);
    });
  });

  describe('when loading the queries', () => {
    beforeEach(() => {
      createWrapper({ props: { isLoadingWorkflows: true } });
    });

    it('renders the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render the workflow list', () => {
      expect(findWorkflowsList().exists()).toBe(false);
    });
  });

  describe('when component is mounted', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    it('renders the workflows list component', () => {
      expect(findWorkflowsList().exists()).toBe(true);
    });

    it('does not render the loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('passes correct props to AgentFlowList', () => {
      expect(findWorkflowsList().props()).toMatchObject({
        showProjectInfo: false,
        showEmptyState: false,
        workflows: expect.any(Array),
        workflowsPageInfo: expect.any(Object),
      });
    });
  });

  describe('filtering and sorting', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    const expectQueryVariablesUpdatedEvent = (expectedPayload) => {
      const emittedEvents = wrapper.emitted('query-variables-updated');
      expect(emittedEvents).toHaveLength(1);
      expect(emittedEvents[0]).toEqual([expectedPayload]);
    };

    it('renders the filtered search bar with correct props', () => {
      expect(findFilteredSearchBar().exists()).toBe(true);
      expect(findFilteredSearchBar().props()).toMatchObject({
        namespace: 'duo-agents-platform',
        searchInputPlaceholder: 'Search for a session',
        syncFilterAndSort: true,
        termsAsTokens: true,
        initialSortBy: 'UPDATED_DESC',
      });
    });

    it('renders the filtered search bar with sort options', () => {
      expect(findFilteredSearchBar().props('sortOptions')).toEqual([
        {
          id: 1,
          title: 'Created date',
          sortDirection: {
            descending: 'CREATED_DESC',
            ascending: 'CREATED_ASC',
          },
        },
        {
          id: 2,
          title: 'Updated date',
          sortDirection: {
            descending: 'UPDATED_DESC',
            ascending: 'UPDATED_ASC',
          },
        },
      ]);
    });

    it('renders the filtered search bar with filter tokens when flow types are available', () => {
      const tokens = findFilteredSearchBar().props('tokens');

      expect(tokens).toHaveLength(2);

      expect(tokens[0]).toMatchObject({
        type: 'flow-name',
        title: 'Flow',
        icon: 'flow-ai',
        unique: true,
      });
      expect(tokens[0].options).toEqual(
        mockFlowTypesNodes.map((node) => ({
          value: node.foundationalFlowReference,
          title: node.name,
        })),
      );

      expect(tokens[1]).toMatchObject({
        type: 'flow-status-group',
        title: 'Status',
        icon: 'status',
        unique: true,
      });
      expect(tokens[1].options).toEqual([
        { value: 'ACTIVE', title: 'Active' },
        { value: 'PAUSED', title: 'Paused' },
        { value: 'AWAITING_INPUT', title: 'Awaiting input' },
        { value: 'COMPLETED', title: 'Completed' },
        { value: 'FAILED', title: 'Failed' },
        { value: 'CANCELED', title: 'Canceled' },
      ]);
    });

    describe('when no flow types are available or query fails', () => {
      it.each`
        description                  | apolloHandlers
        ${'no flow types available'} | ${[[getFlowTypesQuery, mockEmptyFlowTypesHandler]]}
        ${'flow types query fails'}  | ${[[getFlowTypesQuery, mockFlowTypesErrorHandler]]}
      `('does not render the flow token when $description', async ({ apolloHandlers }) => {
        await createWrapper({ apolloHandlers });

        const tokens = findFilteredSearchBar().props('tokens');
        expect(tokens).toHaveLength(1);
        expect(tokens[0]).toMatchObject({
          type: 'flow-status-group',
          title: 'Status',
          icon: 'status',
          unique: true,
        });
      });
    });

    describe('when hasInitialWorkflows is false', () => {
      beforeEach(async () => {
        await createWrapper({ props: { hasInitialWorkflows: false } });
      });

      it('does not render the filtered search bar', () => {
        expect(findFilteredSearchBar().exists()).toBe(false);
      });
    });

    describe('when sorting', () => {
      it('emits query-variables-updated event when on-sort is triggered', () => {
        findFilteredSearchBar().vm.$emit('on-sort', 'UPDATED_DESC');

        expectQueryVariablesUpdatedEvent({
          sort: 'UPDATED_DESC',
          pagination: { before: null, after: null, first: 20, last: null },
          filters: {},
          updatedAfter: null,
        });
      });
    });

    describe('when filtering', () => {
      describe('with valid flow-name token', () => {
        it('emits query-variables-updated event with processed filter parameters', () => {
          const filters = [{ type: 'flow-name', value: { data: 'convert_to_gitlab_ci' } }];

          findFilteredSearchBar().vm.$emit('on-filter', filters);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: { type: 'convert_to_gitlab_ci' },
            updatedAfter: null,
          });
        });
      });

      describe('with valid flow-status-group token', () => {
        it('emits query-variables-updated event with processed filter parameters', () => {
          const filters = [{ type: 'flow-status-group', value: { data: 'PAUSED' } }];

          findFilteredSearchBar().vm.$emit('on-filter', filters);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: { statusGroup: 'PAUSED' },
            updatedAfter: null,
          });
        });
      });

      describe('with unsupported free text search', () => {
        it('emits query-variables-updated event with processed filter parameters', () => {
          const filters = [{ type: 'filtered-search-term', value: { data: 'software dev' } }];

          findFilteredSearchBar().vm.$emit('on-filter', filters);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: { search: 'software dev' },
            updatedAfter: null,
          });
        });
      });

      describe('when filters are cleared', () => {
        it('emits query-variables-updated event with empty filters', () => {
          findFilteredSearchBar().vm.$emit('on-filter', []);

          expectQueryVariablesUpdatedEvent({
            sort: 'UPDATED_DESC',
            pagination: { before: null, after: null, first: 20, last: null },
            filters: {},
            updatedAfter: null,
          });
        });
      });
    });
  });

  describe('time range filter', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('when time range is set to "all"', () => {
      it('emits query-variables-updated event with updatedAfter as null', () => {
        findTimeRangeDropdown().vm.$emit('select', 'all');

        expect(wrapper.emitted('query-variables-updated')).toEqual([
          [
            {
              sort: 'UPDATED_DESC',
              pagination: { before: null, after: null, first: 20, last: null },
              filters: {},
              updatedAfter: null,
            },
          ],
        ]);
      });
    });

    describe('when time range is set to "available"', () => {
      it('emits query-variables-updated event with updatedAfter set to 30 days ago', () => {
        findTimeRangeDropdown().vm.$emit('select', 'available');

        expect(wrapper.emitted('query-variables-updated')).toEqual([
          [
            {
              sort: 'UPDATED_DESC',
              pagination: { before: null, after: null, first: 20, last: null },
              filters: {},
              updatedAfter: '2020-06-06T00:00:00.000Z',
            },
          ],
        ]);
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      await createWrapper();
    });

    describe('when next page is requested', () => {
      it('emits query-variables-updated event with correct parameters', () => {
        findWorkflowsList().vm.$emit('next-page');

        expect(wrapper.emitted('query-variables-updated')).toEqual([
          [
            {
              sort: 'UPDATED_DESC',
              pagination: {
                before: null,
                after: 'asdf',
                first: 20,
                last: null,
              },
              filters: {},
              updatedAfter: null,
            },
          ],
        ]);
      });
    });

    describe('when previous page is requested', () => {
      it('emits query-variables-updated event with correct parameters', () => {
        findWorkflowsList().vm.$emit('prev-page');

        expect(wrapper.emitted('query-variables-updated')).toEqual([
          [
            {
              sort: 'UPDATED_DESC',
              pagination: {
                after: null,
                before: 'asdf',
                first: null,
                last: 20,
              },
              filters: {},
              updatedAfter: null,
            },
          ],
        ]);
      });
    });
  });

  describe('no credits banner', () => {
    it.each`
      creditsAvailable | shouldShow
      ${true}          | ${false}
      ${false}         | ${true}
    `(
      '$shouldShow when creditsAvailable is $creditsAvailable',
      async ({ creditsAvailable, shouldShow }) => {
        await createWrapper({ provide: { creditsAvailable } });

        expect(findNoCreditsBanner().exists()).toBe(shouldShow);
      },
    );

    it('does not render the no credits banner when billing is forbidden', async () => {
      await createWrapper({ provide: { creditsAvailable: false, billingForbidden: true } });

      expect(findNoCreditsBanner().exists()).toBe(false);
    });
  });

  describe('usage billing forbidden banner', () => {
    it('does not render when credits are available', async () => {
      await createWrapper({ provide: { creditsAvailable: true, billingForbidden: true } });

      expect(findUsageBillingForbiddenBanner().exists()).toBe(false);
    });

    it('does not render when billing is not forbidden', async () => {
      await createWrapper({ provide: { creditsAvailable: false, billingForbidden: false } });

      expect(findUsageBillingForbiddenBanner().exists()).toBe(false);
    });

    it('renders when credits are unavailable and billing is forbidden', async () => {
      await createWrapper({ provide: { creditsAvailable: false, billingForbidden: true } });

      expect(findUsageBillingForbiddenBanner().exists()).toBe(true);
    });
  });
});
