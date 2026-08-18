import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AgentInventoryCard from 'ee/ai/governance/components/dashboard/cards/agent_inventory_card.vue';
import getDashboardConfiguredAgentsQuery from 'ee/ai/governance/graphql/queries/get_dashboard_configured_agents.query.graphql';

Vue.use(VueApollo);

const consumerNode = (id, name) => ({
  __typename: 'AiCatalogItemConsumer',
  id: `gid://gitlab/Ai::Catalog::ItemConsumer/${id}`,
  item: {
    __typename: 'AiCatalogAgent',
    id: `gid://gitlab/Ai::Catalog::Item/${id}`,
    name,
    itemType: 'agent',
    description: `${name} description`,
  },
});

const configuredItemsResponse = (nodes) => ({
  data: {
    aiCatalogConfiguredItems: {
      __typename: 'AiCatalogItemConsumerConnection',
      nodes,
    },
  },
});

describe('AgentInventoryCard', () => {
  let wrapper;

  const createComponent = ({ provide = {}, handler } = {}) => {
    const apolloProvider = createMockApollo([
      [
        getDashboardConfiguredAgentsQuery,
        handler ?? jest.fn().mockResolvedValue(configuredItemsResponse([])),
      ],
    ]);

    wrapper = mountExtended(AgentInventoryCard, {
      apolloProvider,
      provide: {
        groupId: '1',
        projectId: null,
        groupFullPath: 'gitlab-duo',
        projectFullPath: null,
        ...provide,
      },
    });
  };

  const findRows = () => wrapper.findAllByTestId('agent-inventory-row');
  const findEmptyState = () => wrapper.findByTestId('empty-state');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findViewAllLink = () => wrapper.findByTestId('view-all-link');

  it('renders a row per configured agent', async () => {
    createComponent({
      handler: jest
        .fn()
        .mockResolvedValue(configuredItemsResponse([consumerNode(1, 'Release agent')])),
    });
    await waitForPromises();

    expect(findRows()).toHaveLength(1);
    expect(findRows().at(0).text()).toContain('Release agent');
    expect(findRows().at(0).text()).toContain('Release agent description');
  });

  it('queries agents scoped to the group', async () => {
    const handler = jest.fn().mockResolvedValue(configuredItemsResponse([]));
    createComponent({ handler });
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({ groupId: 'gid://gitlab/Group/1', itemTypes: ['AGENT'], first: 5 }),
    );
  });

  it('queries agents scoped to the project in project mode', async () => {
    const handler = jest.fn().mockResolvedValue(configuredItemsResponse([]));
    createComponent({ provide: { projectId: '2', projectFullPath: 'gitlab-duo/test' }, handler });
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        projectId: 'gid://gitlab/Project/2',
        itemTypes: ['AGENT'],
        first: 5,
      }),
    );
  });

  it('builds the "View all agents" link to the group agents page', async () => {
    createComponent();
    await waitForPromises();

    expect(findViewAllLink().attributes('href')).toBe('/groups/gitlab-duo/-/automate/agents');
  });

  it('shows the empty state when no agents are configured', async () => {
    createComponent();
    await waitForPromises();

    expect(findRows()).toHaveLength(0);
    expect(findEmptyState().exists()).toBe(true);
  });

  it('shows an error alert when the query fails', async () => {
    createComponent({ handler: jest.fn().mockRejectedValue(new Error('failed')) });
    await waitForPromises();

    expect(findAlert().exists()).toBe(true);
  });
});
