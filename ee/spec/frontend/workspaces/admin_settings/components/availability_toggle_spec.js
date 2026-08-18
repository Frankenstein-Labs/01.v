import { GlToggle } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';

import mappedOrganizationClusterAgentsQuery from 'ee/workspaces/admin_settings/graphql/queries/organization_mapped_agents.query.graphql';
import createClusterAgentMappingMutation from 'ee/workspaces/admin_settings/graphql/mutations/create_org_cluster_agent_mapping.mutation.graphql';
import deleteClusterAgentMappingMutation from 'ee/workspaces/admin_settings/graphql/mutations/delete_org_cluster_agent_mapping.mutation.graphql';
import ClusterAgentAvailabilityToggle from 'ee/workspaces/admin_settings/components/availability_toggle.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { logError } from '~/lib/logger';

import {
  DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT,
  CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT,
  ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT,
  CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR,
  DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR,
} from '../../mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/logger');

const MOCK_ORG_ID = 'gid://gitlab/Organizations::Organization/1';
const MOCK_AGENT_ID = 'gid://gitlab/Clusters::Agent/6';

describe('workspaces/admin_settings/components/availability_toggle.vue', () => {
  let createOrgClusterAgentMappingMutationHandler;
  let deleteOrgClusterAgentMappingMutationHandler;
  let apolloProvider;
  let wrapper;

  const setupApolloProvider = (
    MOCK_CREATE_RESULT = CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT,
    MOCK_DELETE_RESULT = DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT,
  ) => {
    createOrgClusterAgentMappingMutationHandler = jest
      .fn()
      .mockResolvedValueOnce(MOCK_CREATE_RESULT);
    deleteOrgClusterAgentMappingMutationHandler = jest
      .fn()
      .mockResolvedValueOnce(MOCK_DELETE_RESULT);

    apolloProvider = createMockApollo([
      [createClusterAgentMappingMutation, createOrgClusterAgentMappingMutationHandler],
      [deleteClusterAgentMappingMutation, deleteOrgClusterAgentMappingMutationHandler],
    ]);

    apolloProvider.clients.defaultClient.writeQuery({
      query: mappedOrganizationClusterAgentsQuery,
      variables: {
        organizationId: MOCK_ORG_ID,
      },
      data: ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT.data,
    });
  };

  const getAgentFromMappedAgentsStore = (agentId) => {
    const data = apolloProvider.clients.defaultClient.cache.readQuery({
      query: mappedOrganizationClusterAgentsQuery,
      variables: {
        organizationId: MOCK_ORG_ID,
      },
    });

    const mappedAgents = data.organization.mappedAgents.nodes;
    return mappedAgents.filter((agent) => agent.id === agentId);
  };

  const buildWrapper = async (propsData = {}) => {
    wrapper = shallowMount(ClusterAgentAvailabilityToggle, {
      apolloProvider,
      propsData: {
        agentId: MOCK_AGENT_ID,
        isMapped: true,
        ...propsData,
      },
      provide: {
        organizationId: MOCK_ORG_ID,
      },
    });

    await waitForPromises();
  };

  const findToggle = () => wrapper.findComponent(GlToggle);
  const findAvailabilityText = () => wrapper.find('[data-test-id="availability-text"]');
  const findErrorMessage = () => wrapper.find('[data-test-id="error-message"]');

  describe('when agent is mapped', () => {
    beforeEach(() => {
      setupApolloProvider();
      buildWrapper({
        isMapped: true,
      });
    });

    it('renders toggle with correct text', () => {
      expect(findToggle().props('label')).toEqual('Available');
      expect(findToggle().props('value')).toBe(true);
      expect(findAvailabilityText().text()).toEqual('Available');
    });

    it('calls delete org cluster agent mutation on toggle', async () => {
      findToggle().vm.$emit('change');
      await nextTick();

      expect(deleteOrgClusterAgentMappingMutationHandler).toHaveBeenCalledTimes(1);
      expect(deleteOrgClusterAgentMappingMutationHandler).toHaveBeenCalledWith({
        input: {
          organizationId: MOCK_ORG_ID,
          clusterAgentId: MOCK_AGENT_ID,
        },
      });
    });

    it('removes agent from mappedAgents data in store when mutation is successful', async () => {
      // This agent ID exists in ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT
      const MOCK_MAPPED_AGENT_ID = 'gid://gitlab/Clusters::Agent/10';

      buildWrapper({
        agentId: MOCK_MAPPED_AGENT_ID,
        isMapped: true,
      });

      expect(getAgentFromMappedAgentsStore(MOCK_MAPPED_AGENT_ID)).toHaveLength(1);

      findToggle().vm.$emit('change');
      await waitForPromises();
      await nextTick();

      expect(findToggle().props('disabled')).toBe(false);
      expect(getAgentFromMappedAgentsStore(MOCK_MAPPED_AGENT_ID)).toHaveLength(0);
    });
  });

  describe('when agent is unmapped', () => {
    beforeEach(() => {
      setupApolloProvider();
      buildWrapper({
        isMapped: false,
      });
    });

    it('renders toggle with correct text', () => {
      expect(findToggle().props('label')).toEqual('Blocked');
      expect(findToggle().props('value')).toBe(false);
      expect(findAvailabilityText().text()).toEqual('Blocked');
    });

    it('calls create org cluster agent mutation on toggle', async () => {
      findToggle().vm.$emit('change');
      await nextTick();

      expect(createOrgClusterAgentMappingMutationHandler).toHaveBeenCalledTimes(1);
      expect(createOrgClusterAgentMappingMutationHandler).toHaveBeenCalledWith({
        input: {
          organizationId: MOCK_ORG_ID,
          clusterAgentId: MOCK_AGENT_ID,
        },
      });
    });

    it('adds agent to mappedAgents data in store when mutation is successful', async () => {
      // This agent ID does not exist in ORGANIZATION_MAPPED_AGENTS_QUERY_RESULT
      const MOCK_UNMAPPED_AGENT_ID = 'gid://gitlab/Clusters::Agent/6';

      buildWrapper({
        agentId: MOCK_UNMAPPED_AGENT_ID,
        isMapped: false,
      });

      expect(getAgentFromMappedAgentsStore(MOCK_UNMAPPED_AGENT_ID)).toHaveLength(0);

      findToggle().vm.$emit('change');
      await waitForPromises();
      await nextTick();

      expect(findToggle().props('disabled')).toBe(false);
      expect(getAgentFromMappedAgentsStore(MOCK_UNMAPPED_AGENT_ID)).toHaveLength(1);
    });
  });

  describe('on mutation error', () => {
    it.each`
      isMapped | createResult                                                   | deleteResult                                                   | expectedErrorMessage
      ${true}  | ${CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT}            | ${DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR} | ${DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR.data.organizationDeleteClusterAgentMapping.errors[0]}
      ${false} | ${CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR} | ${DELETE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT}            | ${CREATE_ORG_CLUSTER_AGENT_MAPPING_MUTATION_RESULT_WITH_ERROR.data.organizationCreateClusterAgentMapping.errors[0]}
    `(
      'handles error when mutation fails when an agent is mapped = $isMapped',
      async ({ isMapped, createResult, deleteResult, expectedErrorMessage }) => {
        setupApolloProvider(createResult, deleteResult);
        buildWrapper({
          isMapped,
        });
        findToggle().vm.$emit('change');
        await waitForPromises();
        await nextTick();

        expect(findToggle().props('disabled')).toBe(false);
        expect(findErrorMessage().text()).toEqual('Unable to complete request. Please try again.');
        expect(logError).toHaveBeenCalledWith(
          'Error updating Workspaces agent availability',
          expectedErrorMessage,
        );
      },
    );
  });
});
