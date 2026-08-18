// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import Vue from 'vue';
import { GlAvatar } from '@gitlab/ui';
import { DuoChatPredefinedPrompts } from '@gitlab/duo-ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import ActiveTrialOrSubscriptionEmptyState from 'ee/ai/duo_agentic_chat/components/active_trial_or_subscription_empty_state.vue';
import DuoChatEmptyStateHeader from 'ee/ai/duo_agentic_chat/components/duo_chat_empty_state_header.vue';
import TanukiAiIcon from 'ee/ai/shared/widgets/tanuki_ai_icon.vue';
import {
  TRACKING_EVENT_VIEW_EMPTY_STATE,
  TRACKING_EVENT_CLICK_AGENT,
  TRACKING_EVENT_CLICK_PROMPT,
  TRACKING_EVENT_CLICK_EXPLORE_AGENTS,
} from 'ee/ai/duo_agentic_chat/constants';

Vue.use(Vuex);

describe('ActiveTrialOrSubscriptionEmptyState', () => {
  let wrapper;
  let store;

  const mockAgents = [
    { id: 'agent-1', name: 'Agent 1', avatarUrl: 'avatar1.png' },
    { id: 'agent-2', name: 'Agent 2', avatarUrl: 'avatar2.png' },
    { id: 'agent-3', name: 'Agent 3', avatarUrl: 'avatar3.png' },
  ];

  const mockPrompts = ['Prompt 1', 'Prompt 2'];

  const defaultProps = {
    agents: mockAgents,
    predefinedPrompts: mockPrompts,
    exploreAiCatalogPath: '/explore-agents',
  };

  const createComponent = ({ props = {}, initialState = {} } = {}) => {
    store = new Vuex.Store({
      state: {
        currentAgent: { id: 'gid://gitlab/Ai::FoundationalChatAgent/chat' },
        ...initialState,
      },
      mutations: {},
      actions: {},
    });

    wrapper = shallowMountExtended(ActiveTrialOrSubscriptionEmptyState, {
      propsData: { ...defaultProps, ...props },
      store,
    });
  };

  const findIcon = () => wrapper.findComponent(TanukiAiIcon);
  const findEmptyStateHeader = () => wrapper.findComponent(DuoChatEmptyStateHeader);
  const findAgentLinks = () => wrapper.findAllComponentsByTestId('agent-link');
  const findPredefinedPrompts = () => wrapper.findComponent(DuoChatPredefinedPrompts);
  const findExploreLink = () => wrapper.findComponentByTestId('explore-agents-link');
  const findAgentAvatars = () => wrapper.findAllComponents(GlAvatar);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the tanuki icon', () => {
      expect(findIcon().exists()).toBe(true);
    });

    it('renders the empty state actions holder', () => {
      expect(findEmptyStateHeader().exists()).toBe(true);
    });

    it('renders predefined prompts component', () => {
      expect(findPredefinedPrompts().exists()).toBe(true);
    });

    it('renders suggested agents', () => {
      expect(findAgentAvatars()).toHaveLength(3);
    });

    it('renders explore agents link', () => {
      expect(findExploreLink().exists()).toBe(true);
    });
  });

  describe('suggested agents', () => {
    it('renders up to 3 suggested agents', () => {
      createComponent();

      expect(findAgentLinks()).toHaveLength(3);
    });

    it('displays agent names and avatars', () => {
      createComponent();

      const links = findAgentLinks();
      expect(links.at(0).text()).toContain('Agent 1');
      expect(links.at(1).text()).toContain('Agent 2');
    });

    it('excludes the current agent from suggestions', () => {
      createComponent({ initialState: { currentAgent: { id: 'agent-1' } } });

      const links = findAgentLinks();
      expect(links).toHaveLength(2);
      expect(links.at(0).text()).toContain('Agent 2');
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('when an agent is clicked', () => {
      beforeEach(async () => {
        await findAgentLinks().at(0).vm.$emit('click');
      });

      it('emits "new-chat" with the agent', () => {
        expect(wrapper.emitted('new-chat')).toEqual([[mockAgents[0]]]);
      });
    });

    describe('when a predefined prompt is clicked', () => {
      beforeEach(() => {
        findPredefinedPrompts().vm.$emit('click', mockPrompts[0]);
      });

      it('emits "send-chat-prompt"', () => {
        expect(wrapper.emitted('send-chat-prompt')).toEqual([[mockPrompts[0]]]);
      });
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks view event on mount', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(TRACKING_EVENT_VIEW_EMPTY_STATE, {}, undefined);
    });

    it('tracks prompt click with label', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      findPredefinedPrompts().vm.$emit('click', mockPrompts[0]);

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACKING_EVENT_CLICK_PROMPT,
        { label: 'Prompt 1' },
        undefined,
      );
    });

    it('tracks agent click with label', async () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findAgentLinks().at(0).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACKING_EVENT_CLICK_AGENT,
        { label: 'Agent 1' },
        undefined,
      );
    });

    it('tracks explore agents link click', async () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
      trackEventSpy.mockClear();

      await findExploreLink().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        TRACKING_EVENT_CLICK_EXPLORE_AGENTS,
        {},
        undefined,
      );
    });
  });
});
