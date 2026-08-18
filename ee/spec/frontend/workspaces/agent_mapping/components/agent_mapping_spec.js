import { nextTick } from 'vue';
import { GlTabs, GlTab, GlBadge } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getSlotFunction } from '~/lib/utils/vue3compat/normalize_render';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AgentMapping from 'ee_component/workspaces/agent_mapping/components/agent_mapping.vue';
import GetAgentsWithMappingStatusQuery from 'ee_component/workspaces/agent_mapping/components/get_agents_with_mapping_status_query.vue';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  ALERT_CONTAINER_SELECTOR,
} from 'ee/workspaces/agent_mapping/constants';
import { stubComponent } from 'helpers/stub_component';
import { NAMESPACE_ID, MAPPED_CLUSTER_AGENT, UNMAPPED_CLUSTER_AGENT } from '../../mock_data';

jest.mock('~/alert');

describe('workspaces/agent_mapping/components/agent_mapping', () => {
  let wrapper;
  const NAMESPACE = 'foo/bar';

  const buildWrapper = ({ mappedAgentsQueryState = {} } = {}) => {
    wrapper = shallowMountExtended(AgentMapping, {
      provide: {
        namespace: NAMESPACE,
      },
      stubs: {
        GetAgentsWithMappingStatusQuery: stubComponent(GetAgentsWithMappingStatusQuery, {
          // Vue 3-style zero-arg render; opt out of @vue/compat's legacy
          // render-function emulation, which misclassifies it.
          compatConfig: { RENDER_FUNCTION: false },
          render() {
            return getSlotFunction(this)?.(mappedAgentsQueryState);
          },
        }),
        GlTabs,
        GlTab,
        GlBadge,
      },
    });
  };
  const findGetAgentsWithMappingStatusQuery = () =>
    wrapper.findComponent(GetAgentsWithMappingStatusQuery);
  const findAllowedAgentsTable = () => wrapper.findComponentByTestId('allowed-agents-table');
  const findAllAgentsTable = () => wrapper.findComponentByTestId('all-agents-table');
  const findAlertContainer = () => wrapper.find(ALERT_CONTAINER_SELECTOR);
  const findAllowedAgentsTab = () => wrapper.findByTestId('allowed-agents-tab');
  const findAllAgentsTab = () => wrapper.findByTestId('all-agents-tab');
  const triggerQueryResultEvent = (result) => {
    findGetAgentsWithMappingStatusQuery().vm.$emit('result', {
      namespaceId: NAMESPACE_ID,
      ...result,
    });
  };

  describe('default', () => {
    beforeEach(() => {
      buildWrapper();
    });

    it('has alert container', () => {
      expect(findAlertContainer().exists()).toBe(true);
    });
  });

  describe('available agents table', () => {
    it('renders GetAgentsWithMappingStatusQuery component and passes namespace path', () => {
      buildWrapper();

      expect(findGetAgentsWithMappingStatusQuery().props('namespace')).toBe(NAMESPACE);
    });

    describe('when GetAgentsWithMappingStatusQuery component emits result event', () => {
      let agents;
      let allowedAgents;

      beforeEach(async () => {
        buildWrapper();

        agents = [
          MAPPED_CLUSTER_AGENT,
          UNMAPPED_CLUSTER_AGENT,
          {
            ...UNMAPPED_CLUSTER_AGENT,
            id: 'agent-3',
            name: 'agent three',
          },
        ];
        allowedAgents = agents.filter(
          (agent) => agent.mappingStatus === AGENT_MAPPING_STATUS_MAPPED,
        );
        triggerQueryResultEvent({ agents });
        await nextTick();
      });

      it('displays the number of mapped agents in the Allowed Agents Tab', () => {
        expect(findAllowedAgentsTab().findComponent(GlBadge).text()).toContain(
          allowedAgents.length.toString(),
        );
      });

      it('displays the number of all unmapped agents in the All Agents Tab', () => {
        expect(findAllAgentsTab().findComponent(GlBadge).text()).toContain(
          agents.length.toString(),
        );
      });

      it('passes namespaceId to all tables', () => {
        expect(findAllowedAgentsTable().props('namespaceId')).toEqual(NAMESPACE_ID);
        expect(findAllAgentsTable().props('namespaceId')).toEqual(NAMESPACE_ID);
      });

      it('passes allowed agents to the allowed agents table', () => {
        expect(findAllowedAgentsTable().props('agents')).toEqual(allowedAgents);
      });

      it('passes all agents to the all agents table', () => {
        expect(findAllAgentsTable().props('agents')).toEqual(agents);
      });

      it('sets displayMappingStatus on all agents table', () => {
        expect(findAllAgentsTable().props('displayMappingStatus')).toBe(true);
      });

      describe('when there are unmapped agents but not mapped agents', () => {
        beforeEach(async () => {
          buildWrapper();

          agents = [
            UNMAPPED_CLUSTER_AGENT,
            {
              ...UNMAPPED_CLUSTER_AGENT,
              id: 'agent-3',
              name: 'agent three',
            },
          ];
          triggerQueryResultEvent({ agents });
          await nextTick();
        });

        it('passes a "no allowed agents" empty message to the allowed agents table', () => {
          expect(findAllowedAgentsTable().props('emptyStateMessage')).toBe(
            'This group has no available agents. Select the <strong>All agents</strong> tab and allow at least one agent.',
          );
        });
      });

      describe('when there are no agents', () => {
        beforeEach(async () => {
          buildWrapper();

          agents = [];
          triggerQueryResultEvent({ agents });
          await nextTick();
        });

        it('passes a "not agents" empty message to the "allowed" and "all agents" tables', () => {
          expect(findAllowedAgentsTable().props('emptyStateMessage')).toBe(
            'This group has no agents. Start by creating an agent.',
          );
          expect(findAllAgentsTable().props('emptyStateMessage')).toBe(
            'This group has no agents. Start by creating an agent.',
          );
        });
      });
    });

    describe('when GetAgentsWithMappingStatusQuery component emits error event', () => {
      beforeEach(() => {
        buildWrapper();

        findGetAgentsWithMappingStatusQuery().vm.$emit('error');
      });

      it('displays error as a danger alert', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Could not load available agents. Refresh the page to try again.',
          containerSelector: ALERT_CONTAINER_SELECTOR,
        });
      });

      it('does not render any table', () => {
        expect(findAllowedAgentsTable().exists()).toBe(false);
        expect(findAllAgentsTable().exists()).toBe(false);
      });
    });

    it('renders AgentsTable component', () => {
      buildWrapper();

      expect(findAllowedAgentsTable().exists()).toBe(true);
    });

    it('provides loading state from the GetAgentsWithMappingStatusQuery to the AgentsTable component', () => {
      buildWrapper({ mappedAgentsQueryState: { loading: true } });

      expect(findAllowedAgentsTable().props('isLoading')).toBe(true);
    });
  });
});
