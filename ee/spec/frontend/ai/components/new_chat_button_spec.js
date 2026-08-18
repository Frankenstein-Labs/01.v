import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlButton, GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

import NewChatButton from 'ee/ai/components/new_chat_button.vue';
import { catalogAgentsFromResponse } from 'ee/ai/duo_agentic_chat/utils/agent_utils';
import getConfiguredAgents from 'ee/ai/graphql/get_configured_agents.query.graphql';
import getFoundationalChatAgents from 'ee/ai/graphql/get_foundational_chat_agents.graphql';
import {
  DUO_CHAT_AGENT_MOCK,
  DUO_FOUNDATIONAL_AGENT_MOCK,
  MOCK_CONFIGURED_AGENTS_RESPONSE,
  MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE,
} from '../duo_agentic_chat/components/mock_data';

jest.mock('ee/ai/duo_agentic_chat/utils/agent_utils', () => ({
  ...jest.requireActual('ee/ai/duo_agentic_chat/utils/agent_utils'),
  catalogAgentsFromResponse: jest.fn(
    jest.requireActual('ee/ai/duo_agentic_chat/utils/agent_utils').catalogAgentsFromResponse,
  ),
}));

const disabledTooltipText = 'An administrator has turned off GitLab Duo for this project.';

Vue.use(VueApollo);
Vue.use(Vuex);

describe('NewChatButton', () => {
  let wrapper;
  let store;

  const configuredAgentsQueryMock = jest.fn().mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
  const aiFoundationalChatAgentsQueryMock = jest
    .fn()
    .mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);

  const createComponent = async ({
    showSuggestionsTab = true,
    chatDisabledReason = '',
    isChatDisabled = false,
    chatDisabledTooltip = '',
    isAgentSelectEnabled = true,
    currentAgent = null,
    routeName = 'agentic_chat_show',
  } = {}) => {
    const apolloProvider = createMockApollo([
      [getConfiguredAgents, configuredAgentsQueryMock],
      [getFoundationalChatAgents, aiFoundationalChatAgentsQueryMock],
    ]);

    store = new Vuex.Store({
      state: {
        messages: [],
        toolMessage: '',
        currentAgent,
      },
      mutations: {
        STORE_CURRENT_AGENT(state, agent) {
          state.currentAgent = agent;
        },
      },
      actions: {
        setCurrentAgent({ commit }, agent) {
          commit('STORE_CURRENT_AGENT', agent);
        },
        addDuoChatMessage: jest.fn(),
        setMessages: jest.fn(),
      },
    });

    wrapper = shallowMountExtended(NewChatButton, {
      apolloProvider,
      store,
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      propsData: {
        projectId: 'gid://gitlab/Project/123',
        namespaceId: 'gid://gitlab/Group/456',
        showSuggestionsTab,
        chatDisabledReason,
        isChatDisabled,
        chatDisabledTooltip,
        isAgentSelectEnabled,
      },
      mocks: {
        $route: { name: routeName, params: {}, path: '/' },
      },
      stubs: {
        GlButton,
        GlCollapsibleListbox,
      },
    });

    await waitForPromises();

    const listbox = wrapper.findComponent(GlCollapsibleListbox);
    if (listbox.exists()) {
      listbox.vm.close = jest.fn();
    }
  };

  const findNewToggle = () => wrapper.findByTestId('ai-new-toggle');
  const findAgentDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findAgentSelectors = () => wrapper.findAllComponents(GlListboxItem);

  describe('catalogAgents query', () => {
    it('uses catalogAgentsFromResponse to transform the Apollo response', async () => {
      await createComponent();

      expect(catalogAgentsFromResponse).toHaveBeenCalled();
    });

    it('passes includeFoundationalConsumers: false with projectId', async () => {
      await createComponent();

      expect(configuredAgentsQueryMock).toHaveBeenCalledWith({
        first: 20,
        includeFoundationalConsumers: false,
        projectId: 'gid://gitlab/Project/123',
      });
    });
  });

  describe('when there are multiple agents', () => {
    beforeEach(async () => {
      await createComponent();
    });

    it('renders dropdown instead of button', () => {
      expect(findAgentDropdown().exists()).toBe(true);
      expect(findAgentSelectors()).toHaveLength(3);
      expect(findNewToggle().exists()).toBe(false);
    });

    it('shows full agent description as tooltip on description text', () => {
      const listItems = wrapper.findAllByTestId('new-agent-description');

      const expectedDescriptions = [
        DUO_CHAT_AGENT_MOCK.description,
        DUO_FOUNDATIONAL_AGENT_MOCK.description,
        'This is my custom agent',
      ];

      listItems.wrappers.forEach((descriptionEl, index) => {
        expect(descriptionEl.attributes('title')).toBe(expectedDescriptions[index]);
      });
    });

    describe('when an agent is clicked', () => {
      beforeEach(async () => {
        const item = findAgentSelectors().at(0); // should return DUO_CHAT_AGENT_MOCK
        item.vm.$emit('select', true);
        await nextTick();
      });

      it('emits new-chat event without payload', () => {
        expect(wrapper.emitted('new-chat')).toHaveLength(1);
        expect(wrapper.emitted('new-chat')[0]).toEqual([]);
      });

      it('updates dropdown to show selected agent', () => {
        expect(findAgentDropdown().props('selected')).toBe(DUO_CHAT_AGENT_MOCK.id);
      });

      it('correctly updates when another agent is selected', async () => {
        const item1 = findAgentSelectors().at(1); // should return DUO_FOUNDATIONAL_AGENT_MOCK
        item1.vm.$emit('select', true);
        await nextTick();
        expect(findAgentDropdown().props('selected')).toBe(DUO_FOUNDATIONAL_AGENT_MOCK.id);
      });
    });

    describe('when the same agent is clicked multiple times', () => {
      let item;

      beforeEach(async () => {
        item = findAgentSelectors().at(0); // should return DUO_CHAT_AGENT_MOCK
        item.vm.$emit('select', true);
        await nextTick();

        // Second click on the same agent which, technically,
        // unselectes the agent in GlCollapsibleListbox with `multiple`
        // (hence the `false`). But we still register the click
        item.vm.$emit('select', false);
        await nextTick();
      });

      it('allows reselecting the same agent', () => {
        // Should emit for every click, allowing reselection
        expect(wrapper.emitted('new-chat')).toHaveLength(2);
        // But there's only one **correct** agent still selected
        expect(findAgentDropdown().props('selected')).toBe(DUO_CHAT_AGENT_MOCK.id);
      });

      it('correctly handles selection of a new agent after the same agent was selected', async () => {
        const item1 = findAgentSelectors().at(1); // should return DUO_FOUNDATIONAL_AGENT_MOCK
        item1.vm.$emit('select', true);
        await nextTick();

        // Should emit for every click, allowing reselection
        expect(wrapper.emitted('new-chat')).toHaveLength(3);
        // But there's only one **correct** agent still selected
        expect(findAgentDropdown().props('selected')).toBe(DUO_FOUNDATIONAL_AGENT_MOCK.id);
      });
    });

    describe('when searching for agents', () => {
      const searchTerm = 'Cool agent';

      it('filters dropdown items based on search term', async () => {
        expect(findAgentDropdown().props('items')).toHaveLength(3);

        findAgentDropdown().vm.$emit('search', searchTerm);
        await nextTick();

        expect(findAgentDropdown().props('items')).toEqual([
          {
            ...DUO_FOUNDATIONAL_AGENT_MOCK,
            text: DUO_FOUNDATIONAL_AGENT_MOCK.name,
            value: DUO_FOUNDATIONAL_AGENT_MOCK.id,
          },
        ]);
      });
    });
  });

  describe('visibleAgents', () => {
    it('hides agents with selectableInChat: false', async () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValue({
        data: {
          aiFoundationalChatAgents: {
            nodes: [
              DUO_CHAT_AGENT_MOCK,
              { ...DUO_FOUNDATIONAL_AGENT_MOCK, selectableInChat: false },
            ],
          },
        },
      });
      configuredAgentsQueryMock.mockResolvedValue({
        data: { aiCatalogConfiguredItems: { nodes: [] } },
      });

      await createComponent();

      // Only DUO_CHAT_AGENT_MOCK is visible; 1 visible agent → button, not dropdown
      expect(findNewToggle().exists()).toBe(true);
      expect(findAgentDropdown().exists()).toBe(false);
    });

    it('shows agents with selectableInChat: true', async () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValue({
        data: {
          aiFoundationalChatAgents: {
            nodes: [
              { ...DUO_CHAT_AGENT_MOCK, selectableInChat: true },
              { ...DUO_FOUNDATIONAL_AGENT_MOCK, selectableInChat: true },
            ],
          },
        },
      });
      configuredAgentsQueryMock.mockResolvedValue({
        data: { aiCatalogConfiguredItems: { nodes: [] } },
      });

      await createComponent();

      // Both agents are visible; 2 visible agents → dropdown
      expect(findAgentDropdown().exists()).toBe(true);
      expect(findNewToggle().exists()).toBe(false);
    });
  });

  describe('when there is only one agent or no agents', () => {
    beforeEach(async () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValue({
        data: { aiFoundationalChatAgents: { nodes: [] } },
      });
      configuredAgentsQueryMock.mockResolvedValue({
        data: { aiCatalogConfiguredItems: { nodes: [] } },
      });

      await createComponent();
    });

    it('renders button instead of dropdown', () => {
      expect(findNewToggle().exists()).toBe(true);
      expect(findAgentDropdown().exists()).toBe(false);
    });

    describe('when button is clicked', () => {
      beforeEach(async () => {
        await findNewToggle().trigger('click');
      });

      it('emits new-chat event', () => {
        expect(wrapper.emitted('new-chat')).toHaveLength(1);
      });
    });
  });

  describe('when Apollo queries fail', () => {
    describe('for catalog agents query', () => {
      const error = new Error('Catalog agents query failed');

      beforeEach(async () => {
        configuredAgentsQueryMock.mockRejectedValueOnce(error);

        await createComponent();
      });

      it('emits new-chat-error with error payload', () => {
        expect(wrapper.emitted('new-chat-error')).toEqual([[error]]);
      });
    });

    describe('for foundational agents query error', () => {
      const error = new Error('Foundational agents query failed');

      beforeEach(async () => {
        configuredAgentsQueryMock.mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
        aiFoundationalChatAgentsQueryMock.mockRejectedValue(error);

        await createComponent();
      });

      it('emits new-chat-error with error payload', () => {
        expect(wrapper.emitted('new-chat-error')).toEqual([[error]]);
      });
    });
  });

  describe('when chat is disabled', () => {
    beforeEach(async () => {
      aiFoundationalChatAgentsQueryMock.mockResolvedValue({
        data: { aiFoundationalChatAgents: { nodes: [] } },
      });
      configuredAgentsQueryMock.mockResolvedValue({
        data: { aiCatalogConfiguredItems: { nodes: [] } },
      });

      await createComponent({ isChatDisabled: true, chatDisabledTooltip: disabledTooltipText });
    });

    it('sets aria-disabled', () => {
      expect(findNewToggle().attributes('aria-disabled')).toBe('true');
      expect(findNewToggle().classes()).toContain('gl-opacity-5');
    });

    it('shows disabled tooltip', () => {
      expect(findNewToggle().attributes('title')).toBe(disabledTooltipText);
    });
  });

  describe('when isAgentSelectEnabled is false', () => {
    beforeEach(async () => {
      await createComponent({ isAgentSelectEnabled: false });
    });

    it('renders button instead of dropdown', () => {
      expect(findNewToggle().exists()).toBe(true);
      expect(findAgentDropdown().exists()).toBe(false);
    });

    it('does not call Apollo queries', () => {
      expect(configuredAgentsQueryMock).not.toHaveBeenCalled();
      expect(aiFoundationalChatAgentsQueryMock).not.toHaveBeenCalled();
    });

    describe('and button is clicked', () => {
      beforeEach(async () => {
        await findNewToggle().trigger('click');
      });

      it('emits new-chat event', () => {
        expect(wrapper.emitted('new-chat')).toHaveLength(1);
      });
    });
  });

  describe('selected agent value in dropdown', () => {
    describe('when currentAgent is set in store', () => {
      beforeEach(async () => {
        // Reset mocks to return multiple agents (needed if previous tests changed them)
        configuredAgentsQueryMock.mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
        aiFoundationalChatAgentsQueryMock.mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);

        await createComponent({ currentAgent: DUO_FOUNDATIONAL_AGENT_MOCK });
      });

      it('displays the currentAgent as selected in dropdown', () => {
        expect(findAgentDropdown().props('selected')).toBe(DUO_FOUNDATIONAL_AGENT_MOCK.id);
      });
    });

    describe('when currentAgent is null and agents are loaded', () => {
      beforeEach(async () => {
        // Reset mocks to return multiple agents
        configuredAgentsQueryMock.mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
        aiFoundationalChatAgentsQueryMock.mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);

        await createComponent({ currentAgent: null });
      });

      it('displays the first agent as selected in dropdown', () => {
        // Observable: dropdown should select the first available agent
        const dropdownItems = findAgentDropdown().props('items');
        const expectedValue = dropdownItems[0]?.id || null;
        expect(findAgentDropdown().props('selected')).toBe(expectedValue);
      });
    });

    describe('race condition: when both currentAgent and agents are null/empty', () => {
      beforeEach(async () => {
        aiFoundationalChatAgentsQueryMock.mockResolvedValue({
          data: { aiFoundationalChatAgents: { nodes: [] } },
        });
        configuredAgentsQueryMock.mockResolvedValue({
          data: { aiCatalogConfiguredItems: { nodes: [] } },
        });

        await createComponent({ currentAgent: null });
      });

      it('renders button instead of dropdown when no agents available', () => {
        // Observable: when no agents, should show button not dropdown
        expect(findNewToggle().exists()).toBe(true);
        expect(findAgentDropdown().exists()).toBe(false);
      });
    });
  });

  describe('agent selection with currentAgent from store', () => {
    const customAgent = DUO_FOUNDATIONAL_AGENT_MOCK;

    beforeEach(async () => {
      // Reset mocks to return multiple agents
      configuredAgentsQueryMock.mockResolvedValue(MOCK_CONFIGURED_AGENTS_RESPONSE);
      aiFoundationalChatAgentsQueryMock.mockResolvedValue(MOCK_FOUNDATIONAL_CHAT_AGENTS_RESPONSE);

      await createComponent({
        currentAgent: customAgent,
        isAgentSelectEnabled: true,
      });
    });

    it('displays currentAgent from store as selected in dropdown', () => {
      // Observable: dropdown should show the agent from store as selected
      expect(findAgentDropdown().props('selected')).toBe(customAgent.id);
    });

    it('uses currentAgent from store for dropdown selection', () => {
      // Observable: verify the dropdown has the correct selected value
      expect(findAgentDropdown().props('selected')).toBe(customAgent.id);
    });

    it('renders dropdown with agent from store selected', () => {
      // Observable: verify dropdown exists and displays correct selection
      expect(findAgentDropdown().exists()).toBe(true);
      expect(findAgentDropdown().props('selected')).toBe(customAgent.id);
    });
  });
});
