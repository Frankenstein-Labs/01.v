import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';

import { logError } from '~/lib/logger';
import mappedOrganizationClusterAgentsQuery from 'ee/workspaces/admin_settings/graphql/queries/organization_mapped_agents.query.graphql';
import organizationWorkspacesClusterAgentsQuery from 'ee/workspaces/admin_settings/graphql/queries/organization_workspaces_cluster_agents.query.graphql';
import GetOrganizationWorkspacesClusterAgentsQuery from 'ee/workspaces/admin_settings/components/get_organization_workspaces_cluster_agents_query.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import {
  ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT,
  ORGANIZATION_WORKSPACES_CLUSTER_AGENTS_QUERY_RESULT,
} from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/logger');

const MOCK_ORG_ID = 'gid://gitlab/Organizations::Organization/1';
const MOCK_AGENTS_RESULT = [
  {
    id: 'gid://gitlab/Clusters::Agent/14',
    isMapped: true,
    group: 'Gitlab Org',
    isConnected: false,
    name: 'midnightowlgarden',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/midnightowlgarden',
    workspacesEnabled: true,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/13',
    isMapped: false,
    group: 'Gitlab Org',
    isConnected: false,
    name: 'coastalechovalley',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/coastalechovalley',
    workspacesEnabled: true,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/12',
    isMapped: true,
    group: 'Gitlab Org',
    isConnected: false,
    name: 'wandingbreezetale',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/wandingbreezetale',
    workspacesEnabled: false,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/11',
    isMapped: false,
    group: 'Gitlab Org',
    isConnected: false,
    name: 'crimsonmapleshadow',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/crimsonmapleshadow',
    workspacesEnabled: false,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/10',
    isMapped: true,
    group: 'Gitlab Org',
    isConnected: true,
    name: 'meadowsageharbor',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/meadowsageharbor',
    workspacesEnabled: true,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/16',
    isMapped: false,
    group: 'Gitlab Org',
    isConnected: true,
    name: 'silvermoonharbor',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/silvermoonharbor',
    workspacesEnabled: true,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/17',
    isMapped: true,
    group: 'Gitlab Org',
    isConnected: true,
    name: 'silvermoonharbor',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/silvermoonharbor',
    workspacesEnabled: false,
  },
  {
    id: 'gid://gitlab/Clusters::Agent/18',
    isMapped: false,
    group: 'Gitlab Org',
    isConnected: true,
    name: 'oceanbreezecliff',
    project: 'gitlab-agent-configurations',
    url: 'http://test.host/gitlab-org/gitlab-agent-configurations/-/cluster_agents/oceanbreezecliff',
    workspacesEnabled: false,
  },
];

describe('workspaces/admin_settings/components/get_organization_workspaces_cluster_agents_query.vue', () => {
  const defaultSlotSpy = jest.fn();
  const mappedOrganizationClusterAgentsQueryHandler = jest.fn();
  const organizationWorkspacesClusterAgentsQueryHandler = jest.fn();
  let wrapper;

  const buildWrapper = async ({ propsData = {} } = {}) => {
    const apolloProvider = createMockApollo(
      [
        [mappedOrganizationClusterAgentsQuery, mappedOrganizationClusterAgentsQueryHandler],
        [organizationWorkspacesClusterAgentsQuery, organizationWorkspacesClusterAgentsQueryHandler],
      ],
      {},
      { typePolicies: { Query: { fields: { organization: { merge: false } } } } },
    );

    wrapper = shallowMount(GetOrganizationWorkspacesClusterAgentsQuery, {
      apolloProvider,
      propsData: {
        organizationId: '',
        ...propsData,
      },
      scopedSlots: {
        default: defaultSlotSpy,
      },
    });

    await waitForPromises();
    await nextTick();
  };
  const buildWrapperWithOrg = () => buildWrapper({ propsData: { organizationId: MOCK_ORG_ID } });

  const setupMappedOrganizationClusterAgentsQueryHandler = (responses) => {
    mappedOrganizationClusterAgentsQueryHandler.mockResolvedValue(responses);
  };
  const setupOrganizationWorkspacesClusterAgentsQueryHandler = (responses) => {
    organizationWorkspacesClusterAgentsQueryHandler.mockResolvedValue(responses);
  };

  beforeEach(() => {
    logError.mockReset();
    defaultSlotSpy.mockReset();
    mappedOrganizationClusterAgentsQueryHandler.mockReset();
    organizationWorkspacesClusterAgentsQueryHandler.mockReset();
  });

  describe('organizationMappedAgents query', () => {
    it('does not execute query when organizationId is not provided', async () => {
      await buildWrapper();

      expect(mappedOrganizationClusterAgentsQueryHandler).not.toHaveBeenCalled();
    });

    it('executes query when organizationId is provided', async () => {
      setupMappedOrganizationClusterAgentsQueryHandler(ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT);

      await buildWrapperWithOrg();

      expect(mappedOrganizationClusterAgentsQueryHandler).toHaveBeenCalledWith({
        organizationId: MOCK_ORG_ID,
      });
    });

    it('returns error data to scoped slot on query error', async () => {
      const mockError = new Error('Some error');
      mappedOrganizationClusterAgentsQueryHandler.mockRejectedValueOnce(mockError);

      await buildWrapperWithOrg();

      const scopedSlotCall = defaultSlotSpy.mock.lastCall[0];
      expect(scopedSlotCall).toMatchObject({
        loading: false,
        pagination: null,
        error: mockError,
        agents: null,
      });
    });
  });

  describe('organizationWorkspacesClusterAgents query', () => {
    it('does not execute query when organizationId is not provided', async () => {
      await buildWrapper();

      expect(organizationWorkspacesClusterAgentsQueryHandler).not.toHaveBeenCalled();
    });

    it('does not execute query when organizationId is provided but organizationMappedAgentsQuery is not successful', async () => {
      mappedOrganizationClusterAgentsQueryHandler.mockRejectedValueOnce(new Error());
      await buildWrapperWithOrg();

      expect(organizationWorkspacesClusterAgentsQueryHandler).not.toHaveBeenCalled();
    });

    it('executes when organizationId is provided and organizationMappedAgentsQuery is successful', async () => {
      setupMappedOrganizationClusterAgentsQueryHandler(ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT);
      setupOrganizationWorkspacesClusterAgentsQueryHandler(
        ORGANIZATION_WORKSPACES_CLUSTER_AGENTS_QUERY_RESULT,
      );
      await buildWrapperWithOrg();

      expect(organizationWorkspacesClusterAgentsQueryHandler).toHaveBeenCalledWith({
        organizationId: MOCK_ORG_ID,
      });
    });

    describe('scoped slot', () => {
      it('triggers error event when query is not successful', async () => {
        setupMappedOrganizationClusterAgentsQueryHandler(ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT);
        const mockError = new Error('Some error');
        organizationWorkspacesClusterAgentsQueryHandler.mockRejectedValueOnce(mockError);

        await buildWrapperWithOrg();

        const scopedSlotCall = defaultSlotSpy.mock.lastCall[0];

        expect(scopedSlotCall).toMatchObject({
          loading: false,
          pagination: null,
          error: mockError,
          agents: null,
        });
      });

      describe('on query success', () => {
        beforeEach(async () => {
          setupMappedOrganizationClusterAgentsQueryHandler(ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT);
          setupOrganizationWorkspacesClusterAgentsQueryHandler(
            ORGANIZATION_WORKSPACES_CLUSTER_AGENTS_QUERY_RESULT,
          );
          await buildWrapperWithOrg();
          await nextTick();
        });

        const getAgentInScopedSlot = (agentId) => {
          return defaultSlotSpy.mock.lastCall[0].agents.find((agent) => agent.id === agentId);
        };

        it('returns correct data to scoped slot', () => {
          const scopedSlotCall = defaultSlotSpy.mock.lastCall[0];
          const expectedPaginationResult = {
            show: true,
            hasPreviousPage: false,
            hasNextPage: true,
            nextPage: wrapper.vm.nextPage,
            prevPage: wrapper.vm.prevPage,
          };

          expect(scopedSlotCall).toMatchObject({
            loading: false,
            pagination: expectedPaginationResult,
            error: null,
            agents: MOCK_AGENTS_RESULT,
          });
        });

        it('returns correct agents to scopped slot when mappedAgents is updated', async () => {
          const MOCK_AGENT_ID = 'gid://gitlab/Clusters::Agent/14';
          const agentResult = MOCK_AGENTS_RESULT.find((agent) => agent.id === MOCK_AGENT_ID);

          const agentBefore = getAgentInScopedSlot(MOCK_AGENT_ID);

          expect(agentBefore).toStrictEqual(agentResult);

          // Unmap the agent
          const newMappedAgentIds =
            ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT.data.organization.mappedAgents.nodes.filter(
              (agent) => agent.id !== MOCK_AGENT_ID,
            );
          const newMappedAgents = new Set(newMappedAgentIds);

          // Directly set the data to simulate Apollo's update
          wrapper.vm.mappedAgents = newMappedAgents;

          await nextTick();

          const agentAfter = getAgentInScopedSlot(MOCK_AGENT_ID);
          const expectedAgentResult = {
            ...agentResult,
            isMapped: false,
          };
          expect(agentAfter).toStrictEqual(expectedAgentResult);
        });

        it.each`
          methodName    | expectedVariables
          ${'nextPage'} | ${{ organizationId: MOCK_ORG_ID, before: null, after: 'eyJpZCI6IjEwIn0' }}
          ${'prevPage'} | ${{ organizationId: MOCK_ORG_ID, before: 'eyJpZCI6IjE0In0', after: null }}
        `(
          'refetches query with correct variables when $methodName is called',
          async ({ methodName, expectedVariables }) => {
            const scopedSlotCall = defaultSlotSpy.mock.lastCall[0];

            await scopedSlotCall.pagination[methodName]();

            expect(organizationWorkspacesClusterAgentsQueryHandler).toHaveBeenCalledTimes(2);
            expect(organizationWorkspacesClusterAgentsQueryHandler).toHaveBeenLastCalledWith(
              expectedVariables,
            );
          },
        );
      });
    });
  });
});
