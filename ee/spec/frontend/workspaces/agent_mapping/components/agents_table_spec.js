import { GlTable, GlLoadingIcon } from '@gitlab/ui';
import { stubComponent } from 'helpers/stub_component';
import { getSlotFunction } from '~/lib/utils/vue3compat/normalize_render';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import AgentDetailsPopover from 'ee_component/workspaces/agent_mapping/components/agent_details_popover.vue';
import AgentsTable from 'ee_component/workspaces/agent_mapping/components/agents_table.vue';
import AgentMappingStatusToggle from 'ee_component/workspaces/agent_mapping/components/agent_mapping_status_toggle.vue';
import ToggleAgentMappingStatusMutation from 'ee_component/workspaces/agent_mapping/components/toggle_agent_mapping_status_mutation.vue';
import { MAPPED_CLUSTER_AGENT, UNMAPPED_CLUSTER_AGENT, NAMESPACE_ID } from '../../mock_data';

describe('workspaces/agent_mapping/components/agents_table', () => {
  let wrapper;
  const EMPTY_STATE_MESSAGE = 'No agents found';
  const agents = [MAPPED_CLUSTER_AGENT, UNMAPPED_CLUSTER_AGENT];
  let ToggleAgentMappingStatusMutationStub;
  let executeToggleAgentMappingStatusMutationFn;

  const buildWrapper = ({ propsData = {}, provide = {} } = {}, mountFn = shallowMountExtended) => {
    executeToggleAgentMappingStatusMutationFn = jest.fn();
    ToggleAgentMappingStatusMutationStub = stubComponent(ToggleAgentMappingStatusMutation, {
      // Vue 3-style zero-arg render; opt out of @vue/compat's legacy
      // render-function emulation, which misclassifies it.
      compatConfig: { RENDER_FUNCTION: false },
      render() {
        return getSlotFunction(this)?.({
          execute: executeToggleAgentMappingStatusMutationFn,
        });
      },
    });

    wrapper = mountFn(AgentsTable, {
      propsData: {
        agents: [],
        emptyStateMessage: EMPTY_STATE_MESSAGE,
        isLoading: false,
        namespaceId: NAMESPACE_ID,
        ...propsData,
      },
      provide: {
        ...provide,
      },
      stubs: {
        ToggleAgentMappingStatusMutation: ToggleAgentMappingStatusMutationStub,
      },
    });
  };
  const findAgentsTable = () => wrapper.findComponent(GlTable);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);

  describe('when loading', () => {
    beforeEach(() => {
      buildWrapper({
        propsData: {
          isLoading: true,
        },
      });
    });

    it('displays loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not display agents table', () => {
      expect(findAgentsTable().exists()).toBe(false);
    });
  });

  describe('when is not loading and agents are available', () => {
    describe('with agents', () => {
      beforeEach(() => {
        buildWrapper({
          propsData: {
            isLoading: false,
            agents: [{}],
          },
        });
      });

      it('does not display loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('displays agents table', () => {
        expect(findAgentsTable().exists()).toBe(true);
      });
    });

    describe('with no agents', () => {
      beforeEach(() => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              agents: [],
            },
          },
          mountExtended,
        );
      });

      it('does not display loading icon', () => {
        expect(findLoadingIcon().exists()).toBe(false);
      });

      it('displays agents table', () => {
        expect(findAgentsTable().exists()).toBe(true);
      });

      it('displays empty message in agents table', () => {
        expect(findAgentsTable().text()).toContain(EMPTY_STATE_MESSAGE);
      });
    });
  });

  describe('with agents', () => {
    beforeEach(() => {
      buildWrapper(
        {
          propsData: {
            isLoading: false,
            agents,
          },
        },
        mountExtended,
      );
    });

    it('does not display loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('displays agents table', () => {
      expect(findAgentsTable().exists()).toBe(true);
    });

    it('displays agents list', () => {
      expect(findAgentsTable().text()).toContain(MAPPED_CLUSTER_AGENT.name);
    });

    it('displays agent data popover', () => {
      const popover = findAgentsTable().findAllComponents(AgentDetailsPopover);
      agents.forEach((agent, index) => {
        expect(popover.at(index).props().agent).toMatchObject(agent);
      });
    });

    describe('when displayMappingStatus is true', () => {
      it('displays agent status using label', () => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              displayMappingStatus: true,
              agents,
            },
          },
          mountExtended,
        );
        const labels = wrapper
          .findAllComponentsByTestId('agent-mapping-status-label')
          .wrappers.map((labelWrapper) => ({
            text: labelWrapper.text(),
            variant: labelWrapper.props().variant,
          }));

        expect(labels).toEqual([
          { text: 'Allowed', variant: 'success' },
          { text: 'Blocked', variant: 'danger' },
        ]);
      });
    });

    describe('when displayAgentStatus is false', () => {
      it('does not display agent status using label', () => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              mappingStatus: false,
              agents,
            },
          },
          mountExtended,
        );

        expect(wrapper.findAllByTestId('agent-mapping-status-label')).toHaveLength(0);
      });
    });

    describe('when canAdminClusterAgentMapping is true', () => {
      beforeEach(() => {
        buildWrapper(
          {
            propsData: {
              isLoading: false,
              agents,
            },
            provide: {
              canAdminClusterAgentMapping: true,
            },
          },
          mountExtended,
        );
      });

      it('displays actions column', () => {
        expect(findAgentsTable().text()).toContain('Action');

        const toggles = findAgentsTable().findAllComponents(AgentMappingStatusToggle);
        const mutations = findAgentsTable().findAllComponents(ToggleAgentMappingStatusMutationStub);

        agents.forEach((agent, index) => {
          expect(toggles.at(index).props().agent).toMatchObject(agent);
          expect(mutations.at(index).props()).toMatchObject({
            agent,
            namespaceId: NAMESPACE_ID,
          });
        });
      });

      describe('when action toggle emits toggle event', () => {
        it('executes the toggle mapping agent status mutation', () => {
          findAgentsTable().findAllComponents(AgentMappingStatusToggle).at(0).vm.$emit('toggle');

          expect(executeToggleAgentMappingStatusMutationFn).toHaveBeenCalled();
        });
      });
    });
  });

  describe('when canAdminClusterAgentMapping is false', () => {
    it('does not display actions column', () => {
      buildWrapper(
        {
          propsData: {
            isLoading: false,
            agents,
          },
          provide: {
            canAdminClusterAgentMapping: false,
          },
        },
        mountExtended,
      );
      expect(findAgentsTable().text()).not.toContain('Actions');
      expect(findAgentsTable().findAllComponents(AgentMappingStatusToggle)).toHaveLength(0);
    });
  });
});
