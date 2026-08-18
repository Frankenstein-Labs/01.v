import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogItemsIndex from 'ee/ai/catalog/pages/ai_catalog_items_index.vue';
import aiCatalogItemsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_items.query.graphql';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';
import { mockAgents, mockCatalogItemsResponse, mockCatalogEmptyItemsResponse } from '../mock_data';
import { createIntegrationWrapper, EXPLORE_PROVIDE, ROUTE_PRESETS } from './helpers';

const createAgentsQueryHandler = (response) => jest.fn().mockResolvedValue(response);

describe('Agent — list page integration', () => {
  const mountListPage = ({ queryHandler, provide = {}, glFeatures = {} } = {}) => {
    const handler = queryHandler || createAgentsQueryHandler(mockCatalogItemsResponse);
    return createIntegrationWrapper(AiCatalogItemsIndex, {
      props: { itemType: AI_CATALOG_TYPE_AGENT },
      provide: { ...EXPLORE_PROVIDE, glFeatures, ...provide },
      apolloHandlers: [[aiCatalogItemsQuery, handler]],
      route: ROUTE_PRESETS.agentList,
    });
  };

  it('renders agent items from query response', async () => {
    const { wrapper } = mountListPage();
    await waitForPromises();

    const items = wrapper.findAllByTestId('ai-catalog-item');
    expect(items).toHaveLength(mockAgents.length);
    expect(wrapper.text()).toContain('Test AI Agent 1');
    expect(wrapper.text()).toContain('Test AI Agent 2');
  });

  it('shows empty state when no agents exist', async () => {
    const { wrapper } = mountListPage({
      queryHandler: createAgentsQueryHandler(mockCatalogEmptyItemsResponse),
    });
    await waitForPromises();

    expect(wrapper.findAllByTestId('ai-catalog-item')).toHaveLength(0);
    expect(wrapper.text()).toContain('Get started with the AI Catalog');
  });

  it('includes third-party flows in query when aiCatalogThirdPartyFlows feature is enabled', async () => {
    const handler = createAgentsQueryHandler(mockCatalogItemsResponse);
    mountListPage({ queryHandler: handler, glFeatures: { aiCatalogThirdPartyFlows: true } });
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        itemTypes: [AI_CATALOG_TYPE_AGENT, AI_CATALOG_TYPE_THIRD_PARTY_FLOW],
      }),
    );
  });

  it('excludes third-party flows in query when feature is disabled', async () => {
    const handler = createAgentsQueryHandler(mockCatalogItemsResponse);
    mountListPage({ queryHandler: handler, glFeatures: { aiCatalogThirdPartyFlows: false } });
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        itemTypes: [AI_CATALOG_TYPE_AGENT],
      }),
    );
  });

  it('sends search term to query when user submits search', async () => {
    const handler = createAgentsQueryHandler(mockCatalogItemsResponse);
    const { wrapper } = mountListPage({ queryHandler: handler });
    await waitForPromises();

    wrapper
      .findComponent(FilteredSearchBar)
      .vm.$emit('on-filter', [{ type: 'filtered-search-term', value: { data: 'user search' } }]);
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        search: 'user search',
      }),
    );
  });

  it('pre-populates search input and sends search term from URL to query', async () => {
    const handler = createAgentsQueryHandler(mockCatalogItemsResponse);

    const { wrapper } = createIntegrationWrapper(AiCatalogItemsIndex, {
      props: { itemType: AI_CATALOG_TYPE_AGENT },
      provide: EXPLORE_PROVIDE,
      apolloHandlers: [[aiCatalogItemsQuery, handler]],
      route: { ...ROUTE_PRESETS.agentList, query: { search: 'test query' } },
    });
    await waitForPromises();

    const filteredSearchBar = wrapper.findComponent(FilteredSearchBar);
    expect(filteredSearchBar.exists()).toBe(true);

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        search: 'test query',
      }),
    );
  });

  it('sends sort value to query when user changes sort option', async () => {
    const handler = createAgentsQueryHandler(mockCatalogItemsResponse);
    const { wrapper } = mountListPage({ queryHandler: handler });
    await waitForPromises();

    wrapper.findComponent(FilteredSearchBar).vm.$emit('on-sort', 'STAR_COUNT_DESC');
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        sort: 'STAR_COUNT_DESC',
      }),
    );
  });

  it('passes null sort to query by default (catalog priority ordering)', async () => {
    const handler = createAgentsQueryHandler(mockCatalogItemsResponse);
    mountListPage({ queryHandler: handler });
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        sort: null,
      }),
    );
  });
});
