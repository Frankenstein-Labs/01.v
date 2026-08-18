<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import { GlAvatar, GlIcon, GlLink } from '@gitlab/ui';
import { DuoChatPredefinedPrompts } from '@gitlab/duo-ui';
import { InternalEvents } from '~/tracking';
import TanukiAiIcon from '../../shared/widgets/tanuki_ai_icon.vue';
import {
  TRACKING_EVENT_VIEW_EMPTY_STATE,
  TRACKING_EVENT_CLICK_AGENT,
  TRACKING_EVENT_CLICK_PROMPT,
  TRACKING_EVENT_CLICK_EXPLORE_AGENTS,
  SUGGESTED_AGENTS_LIMIT,
  DEFAULT_AGENT_ID,
} from '../constants';
import DuoChatEmptyStateHeader from './duo_chat_empty_state_header.vue';

export default {
  name: 'ActiveTrialOrSubscriptionEmptyState',
  components: {
    DuoChatEmptyStateHeader,
    DuoChatPredefinedPrompts,
    GlAvatar,
    GlIcon,
    GlLink,
    TanukiAiIcon,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    agents: {
      type: Array,
      required: true,
    },
    predefinedPrompts: {
      type: Array,
      required: true,
    },
    exploreAiCatalogPath: {
      type: String,
      required: true,
    },
  },
  emits: ['new-chat', 'send-chat-prompt'],
  computed: {
    ...mapState(['currentAgent']),
    suggestedAgents() {
      const currentAgentId = this.currentAgent?.id || DEFAULT_AGENT_ID;
      const filtered = this.agents.filter((agent) => {
        return agent.id !== currentAgentId;
      });

      return filtered.slice(0, SUGGESTED_AGENTS_LIMIT);
    },
  },
  mounted() {
    this.trackEvent(TRACKING_EVENT_VIEW_EMPTY_STATE);
  },
  methods: {
    handleAgentClick(agent) {
      this.trackEvent(TRACKING_EVENT_CLICK_AGENT, { label: agent.name });
      this.$emit('new-chat', agent);
    },
    sendPredefinedPrompt(prompt) {
      this.trackEvent(TRACKING_EVENT_CLICK_PROMPT, { label: prompt });
      this.$emit('send-chat-prompt', prompt);
    },
    handleExploreAgentsClick() {
      this.trackEvent(TRACKING_EVENT_CLICK_EXPLORE_AGENTS);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-w-full gl-flex-col gl-gap-4 gl-py-8">
    <tanuki-ai-icon />

    <duo-chat-empty-state-header />

    <span class="gl-font-bold">{{ s__('DuoAgenticChat|Chat about different topics') }}</span>

    <duo-chat-predefined-prompts
      key="predefined-prompts"
      :prompts="predefinedPrompts"
      @click="sendPredefinedPrompt"
    />

    <div class="gl-py-5">
      <span class="gl-font-bold">{{ s__('DuoAgenticChat|Chat with different agents') }}</span>
      <p class="gl-my-4">
        {{ s__('DuoAgenticChat|Get targeted help for tasks with specialized agents') }}
      </p>

      <div class="gl-grid gl-grid-cols-2 gl-gap-5">
        <gl-link
          v-for="agent in suggestedAgents"
          :key="agent.id"
          data-testid="agent-link"
          class="gl-flex gl-items-center gl-rounded-full gl-bg-gray-50 gl-p-2 hover:gl-no-underline"
          variant="meta"
          @click="handleAgentClick(agent)"
        >
          <gl-avatar :src="agent.avatarUrl" :alt="agent.name" :size="32" class="gl-shrink-0" />
          <span class="gl-ml-2 gl-min-w-0 gl-truncate gl-font-bold" :title="agent.name">{{
            agent.name
          }}</span>
        </gl-link>

        <div class="gl-col-span-2 gl-text-center">
          <gl-link
            class="gl-rounded-full gl-bg-gray-50 gl-px-6 gl-py-2 hover:gl-no-underline"
            :href="exploreAiCatalogPath"
            variant="meta"
            data-testid="explore-agents-link"
            @click="handleExploreAgentsClick"
          >
            <gl-icon name="plus" />
            <span class="gl-font-bold">{{ s__('Agents|Explore other agents') }}</span>
          </gl-link>
        </div>
      </div>
    </div>
  </div>
</template>
