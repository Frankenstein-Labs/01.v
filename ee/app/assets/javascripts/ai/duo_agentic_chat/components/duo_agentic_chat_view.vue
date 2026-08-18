<script>
import { throttle } from 'lodash-es';

import {
  MESSAGE_MODEL_ROLES,
  DuoChatLoader,
  DuoChatPredefinedPrompts,
  DuoChatContextConversation as DuoChatConversation,
  DuoChatThreads,
} from '@gitlab/duo-ui';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';
import { CHAT_RESET_MESSAGE } from 'ee/ai/tanuki_bot/constants';
import { s__, sprintf } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { MESSAGE_SUB_TYPE_TIER_ACCESS_DENIED } from '../constants';
import DuoChatHeader from './duo_chat_header.vue';
import SessionPillsBar from './session_pills/session_pills_bar.vue';
import PromptTextarea from './prompt_textarea.vue';

export const i18n = {
  CHAT_DEFAULT_TITLE: s__('DuoAgenticChat|GitLab Duo Agentic Chat'),
  CHAT_HISTORY_TITLE: s__('DuoAgenticChat|Chat history'),
  CHAT_DISCLAIMER: s__('DuoAgenticChat|Responses may be inaccurate. Verify before use.'),
  CHAT_EMPTY_STATE_EMOJI: '👋',
  CHAT_EMPTY_STATE_TITLE: s__(
    'DuoAgenticChat|I am GitLab Duo Agentic Chat, your personal AI-powered assistant.',
  ),
  CHAT_EMPTY_STATE_DESCRIPTION: s__('DuoAgenticChat|How can I help you today?'),
  CHAT_PROMPT_PLACEHOLDER_DEFAULT: s__("DuoAgenticChat|Let's work through this together..."),
  CHAT_MODEL_PLACEHOLDER: s__('DuoAgenticChat|GitLab Duo Agentic Chat'),
  CHAT_PROMPT_PLACEHOLDER_WITH_COMMANDS: s__('DuoAgenticChat|Type /help to learn more'),
  CHAT_SUBMIT_LABEL: s__('DuoAgenticChat|Send chat message.'),
  CHAT_CANCEL_LABEL: s__('DuoAgenticChat|Cancel'),
  CHAT_DEFAULT_PREDEFINED_PROMPTS: [
    s__('DuoAgenticChat|How do I change my password in GitLab?'),
    s__('DuoAgenticChat|How do I fork a project?'),
    s__('DuoAgenticChat|How do I clone a repository?'),
    s__('DuoAgenticChat|How do I create a template?'),
  ],
};

const isMessage = (item) => Boolean(item) && item?.role;

const itemsValidator = (items) => items.every(isMessage);

const isThread = (thread) =>
  (typeof thread === 'object' &&
    typeof thread.id === 'string' &&
    typeof thread.lastUpdatedAt === 'string') ||
  (typeof thread.updatedAt === 'string' &&
    (thread.title === null || typeof thread.title === 'string' || typeof thread.goal === 'string'));

const threadListValidator = (threads) => threads.every(isThread);

const localeValidator = (value) => {
  try {
    Intl.getCanonicalLocales(value);
    return true;
  } catch {
    return false;
  }
};

export default {
  name: 'DuoAgenticChatView',
  components: {
    DuoChatLoader,
    DuoChatPredefinedPrompts,
    DuoChatConversation,
    DuoChatHeader,
    DuoChatThreads,
    SessionPillsBar,
    PromptTextarea,
  },
  mixins: [glSlotsMixin],
  provide() {
    return {
      markdownClass: 'md',
    };
  },
  props: {
    /**
     * The name of the agent to display in the empty state.
     */
    agentName: {
      type: String,
      required: false,
      default: null,
    },
    /**
     * The title of the chat/feature.
     */
    title: {
      type: String,
      required: false,
      default: i18n.CHAT_DEFAULT_TITLE,
    },
    /**
     * The GraphQL global id of the active agent, used to derive a stable avatar color.
     */
    agentId: {
      type: String,
      required: false,
      default: null,
    },
    /**
     * The avatar image URL of the active agent (if any).
     */
    agentAvatarUrl: {
      type: String,
      required: false,
      default: null,
    },
    /**
     * Array of messages to display in the chat.
     */
    messages: {
      type: Array,
      required: false,
      default: () => [],
      validator: itemsValidator,
    },
    /**
     * The chat page that should be shown.
     */
    multiThreadedView: {
      type: String,
      required: false,
      default: DUO_CHAT_VIEWS.LIST,
      validator: (value) => [DUO_CHAT_VIEWS.LIST, DUO_CHAT_VIEWS.CHAT].includes(value),
    },

    /**
     * A non-recoverable error message to display in the chat.
     */
    error: {
      type: String,
      required: false,
      default: '',
    },
    /**
     * Chat state object that contains enablement state and optional reason message.
     * When chat is disabled (isEnabled: false), a reason message must be provided.
     */
    chatState: {
      type: Object,
      required: false,
      default: () => ({ isEnabled: true, reason: null }),
      validator: (value) => {
        // If chat is disabled, reason must be provided
        if (!value.isEnabled && !value.reason) {
          return false;
        }
        return true;
      },
    },
    /**
     * Array of threads to display in the thread list.
     */
    threadList: {
      type: Array,
      required: false,
      default: () => [],
      validator: threadListValidator,
    },

    loadingThreadList: {
      type: Boolean,
      required: false,
      default: false,
    },

    /**
     * Whether the chat is currently fetching a response from AI.
     */
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * Whether the conversational interfaces should be enabled.
     */
    isChatAvailable: {
      type: Boolean,
      required: false,
      default: true,
    },
    /**
     * Whether the insertCode feature should be available.
     */
    enableCodeInsertion: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * Array of predefined prompts to display in the chat to start a conversation.
     */
    predefinedPrompts: {
      type: Array,
      required: false,
      default: () => i18n.CHAT_DEFAULT_PREDEFINED_PROMPTS,
    },
    /**
     * The current tool's name to display in the loading message while waiting for a response from AI. Refer the `DuoChatLoader` component for more information.
     */
    toolName: {
      type: String,
      required: false,
      default: i18n.CHAT_DEFAULT_TITLE,
    },
    /**
     * Whether the header should be displayed.
     */
    showHeader: {
      type: Boolean,
      required: false,
      default: true,
    },
    /**
     * Override the default empty state title text.
     */
    emptyStateTitle: {
      type: String,
      required: false,
      default: null,
    },
    /**
     * Override the default chat prompt placeholder text.
     */
    chatPromptPlaceholder: {
      type: String,
      required: false,
      default: '',
    },
    /**
     * Whether the chat is running in multi-threaded mode
     */
    isMultithreaded: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * The preferred locale for the chat interface.
     * Follows BCP 47 language tag format (e.g., 'en-US', 'fr-FR', 'es-ES').
     */
    preferredLocale: {
      type: Array,
      required: false,
      default: () => ['en-US', 'en'],
      validator: localeValidator,
    },
    /**
     * Whether the chat should show the feedback link on the assistant messages.
     */
    withFeedback: {
      type: Boolean,
      required: false,
      default: true,
    },
    /**
     * Whether the tool call is currently being processed.
     */
    isToolApprovalProcessing: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * Optional parameter to pass in the working directory - needed for MessageMap Tool type
     */
    workingDirectory: {
      type: String,
      required: false,
      default: '',
    },
    /**
     * Array of trusted hostnames (e.g., ['gitlab.com', 'example.com'])
     * that are allowed to render as clickable links in markdown content.
     * Links to other domains will not be clickable.
     */
    trustedUrls: {
      type: Array,
      required: false,
      default: () => [],
      validator: (urls) => urls.every((url) => typeof url === 'string'),
    },
    /**
     * Whether to show agentic binary feedback (thumbs up/down) instead of the full feedback modal.
     */
    isBinaryFeedbackEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * Whether the manual retry action on assistant messages is enabled. Forwarded
     * to DuoChatConversation which gates the retry button on the latest assistant
     * message. Gated by the `agentic_manual_retry_for_duo_chat_responses` flag.
     */
    isRetryEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * Map of messageId to selected alternative index.
     * Used to track which alternative is currently displayed for each message.
     */
    selectedAlternatives: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    /**
     * Optional array of custom message renderers passed through to MessageMap.
     * Each entry is an object with `component` (Vue component) and `matchMessage` (Function).
     */
    isSaas: {
      type: Boolean,
      required: false,
      default: false,
    },
    messageRenderers: {
      type: Array,
      required: false,
      default() {
        return [];
      },
      validator: (renderers) =>
        renderers.every(
          (r) =>
            r !== null &&
            typeof r === 'object' &&
            typeof r.component === 'object' &&
            typeof r.matchMessage === 'function',
        ),
    },
    webSearchEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: [
    'approve-tool',
    'chat-cancel',
    'chat-hidden',
    'copy-code-snippet',
    'copy-message',
    'delete-thread',
    'deny-tool',
    'get-context-item-content',
    'insert-code-snippet',
    'new-chat',
    'open-file-path',
    'retry-message',
    'select-alternative',
    'send-chat-prompt',
    'web-search-toggled',
    'thread-selected',
    'track-feedback',
    'question-answered',
  ],
  data() {
    return {
      scrolledToBottom: true,
      currentView: this.multiThreadedView,
    };
  },
  computed: {
    shouldShowThreadList() {
      return this.isMultithreaded && this.currentView === DUO_CHAT_VIEWS.LIST;
    },
    hasMessages() {
      return this.messages?.length > 0;
    },
    hasAssistantMessages() {
      return this.messages?.some((msg) => msg.role?.toLowerCase() === 'assistant');
    },
    conversations() {
      if (!this.hasMessages) return [];

      return this.messages.reduce(
        (acc, message) => {
          if (message.content === CHAT_RESET_MESSAGE) {
            acc.push([]);
          } else {
            // Rewrite `tier_access_denied` messages to use 'tool' role + 'tool' type so they
            // fall through to MessageMap and render via MessageTierAccessDenied in SaaS.
            acc[acc.length - 1].push(
              this.isSaas && message.message_sub_type === MESSAGE_SUB_TYPE_TIER_ACCESS_DENIED
                ? { ...message, role: 'tool', message_type: 'tool' }
                : message,
            );
          }
          return acc;
        },
        [[]],
      );
    },
    lastMessage() {
      return this.messages?.[this.messages.length - 1];
    },
    hasFooterControls() {
      return (
        this.glSlots()?.['footer-controls'] &&
        typeof this.glSlots()['footer-controls'] === 'function' &&
        this.glSlots()['footer-controls']()
      );
    },
    emptyStateGreeting() {
      return sprintf(s__('DuoAgenticChat|Hello, I am %{agentName}!'), {
        agentName: this.agentName,
      });
    },
    emptyStateMainText() {
      if (this.emptyStateTitle) {
        return this.emptyStateTitle;
      }
      return i18n.CHAT_EMPTY_STATE_TITLE;
    },
    emptyStateSubText() {
      return i18n.CHAT_EMPTY_STATE_DESCRIPTION;
    },
  },
  watch: {
    multiThreadedView(newView) {
      this.currentView = newView;
    },
    lastMessage(newMessage) {
      if (this.scrolledToBottom || newMessage?.role.toLowerCase() === MESSAGE_MODEL_ROLES.user) {
        // only scroll to bottom on new message if the user hasn't explicitly scrolled up to view an earlier message
        // or if the user has just submitted a new message
        this.scrollToBottom();
      }
    },
  },
  created() {
    this.handleScrollingThrottled = throttle(this.handleScrolling, 200); // Assume a 200ms throttle for example
  },
  mounted() {
    this.scrollToBottom();
  },

  methods: {
    onNewChat(agent) {
      this.$emit('new-chat', agent);

      this.$nextTick(() => {
        this.$refs.promptTextarea?.focusChatInput();
      });
    },
    hideChat() {
      /**
       * Emitted when clicking the cross in the title and the chat gets closed.
       */
      this.$emit('chat-hidden');
    },
    sendPredefinedPrompt(prompt) {
      this.$refs.promptTextarea?.sendPredefinedPrompt(prompt);
    },
    handleScrolling(event) {
      const { scrollTop, offsetHeight, scrollHeight } = event.target;
      this.scrolledToBottom = scrollTop + offsetHeight >= scrollHeight;
    },
    async scrollToBottom() {
      await this.$nextTick();

      this.$refs.anchor?.scrollIntoView?.();
    },
    onPillsBarHeightChange() {
      // The footer resized under the scroll container, but `lastMessage` did not
      // change, so the existing watcher will not re-pin.
      if (!this.scrolledToBottom) return;

      this.scrollToBottom();
    },
    // `focusChatInput` can be called by the parent component via $refs. Ideally, we would mark this
    // as a public method via Vue's `expose` option. However, doing so would cause several tests to
    // fail in Vue 3 because we wrote some assertions directly against the `vm`, which becomes
    // private when `expose` is defined. So we need to _not_ use `expose` and disable
    // vue/no-unused-properties for now.
    // eslint-disable-next-line vue/no-unused-properties
    focusChatInput() {
      this.$refs.promptTextarea?.focusChatInput();
    },
    onTrackFeedback(event) {
      /**
       * Notify listeners about the feedback form submission on a response message.
       * @param {*} event An event, containing the feedback choices and the extended feedback text.
       */
      this.$emit('track-feedback', event);
    },
    onInsertCodeSnippet(e) {
      /**
       * Emit insert-code-snippet event that clients can use to interact with a suggested code.
       * @param {*} event An event containing code string in the "detail.code" field.
       */
      this.$emit('insert-code-snippet', e);
    },
    onCopyCodeSnippet(e) {
      /**
       * Emit copy-code-snippet event that clients can use to interact with a suggested code.
       * @param {*} event An event containing code string in the "detail.code" field.
       */
      this.$emit('copy-code-snippet', e);
    },
    onCopyMessage(e) {
      /**
       * Emit copy-message event that clients can use to copy chat message content.
       * @param {*} event An event containing code string in the "detail.message" field.
       */
      this.$emit('copy-message', e);
    },
    onGetContextItemContent(event) {
      /**
       * Emit get-context-item-content event that tells clients to load the full file content for a selected context item.
       * The fully hydrated context item should be updated in the chat message context item.
       * @param {*} event An event containing the message ID and context item to hydrate
       */
      this.$emit('get-context-item-content', event);
    },
    onSelectThread(thread) {
      /**
       * Emitted when a thread is selected from the history.
       * @param {Object} thread The selected thread object
       */
      this.$emit('thread-selected', thread);
    },
    onDeleteThread(threadId) {
      /**
       * Emitted when a thread is deleted from the history.
       * @param {String} threadId The ID of the thread to delete
       */
      this.$emit('delete-thread', threadId);
    },
    onApproveToolCall() {
      /**
       * Emitted when a user approves a tool call.
       */
      this.$emit('approve-tool');
    },
    onDenyToolCall(reason) {
      /**
       * Emitted when a user denies a tool call.
       * @param {String} reason The reason for denying the tool call.
       */
      this.$emit('deny-tool', reason);
    },
    onOpenFilePath(filePath) {
      /**
       * Emitted when a file path link is clicked in a chat message.
       * @param {String} filePath The file path to open
       */
      this.$emit('open-file-path', filePath);
    },
    onQuestionAnswered($event) {
      this.$emit('question-answered', $event);
    },
  },
  i18n,
};
</script>
<template>
  <div
    id="chat-component"
    class="duo-chat web-only gl-bottom-0 gl-flex gl-max-h-full gl-min-h-0 gl-flex-grow gl-flex-col"
    role="complementary"
    data-testid="chat-component"
  >
    <div
      class="panel-content-inner gl-flex gl-flex-grow gl-flex-col gl-overscroll-contain gl-bg-inherit"
      data-testid="chat-history"
      @scroll="handleScrollingThrottled"
    >
      <duo-chat-header
        v-if="showHeader"
        ref="header"
        :title="
          isMultithreaded && currentView === 'list' ? $options.i18n.CHAT_HISTORY_TITLE : title
        "
        :agent-id="agentId"
        :agent-avatar-url="agentAvatarUrl"
        :error="error"
        :info="hasMessages ? chatState.reason : ''"
        :current-view="currentView"
      >
        <template v-if="glSlots().subheader" #subheader>
          <slot name="subheader"></slot>
        </template>
      </duo-chat-header>

      <duo-chat-threads
        v-if="shouldShowThreadList"
        class="gl-mx-auto gl-w-full gl-max-w-4xl"
        data-testid="duo-chat-threads"
        :threads="threadList"
        :preferred-locale="preferredLocale"
        :loading="loadingThreadList"
        @new-chat="onNewChat"
        @select-thread="onSelectThread"
        @delete-thread="onDeleteThread"
        @close="hideChat"
      />
      <transition-group
        v-else
        mode="out-in"
        tag="section"
        :name="glSlots()['custom-empty-state'] ? '' : 'message'"
        data-testid="chat-messages"
        :class="[
          'duo-chat-history gl-mx-auto gl-w-full gl-max-w-4xl gl-px-4',
          glSlots()['custom-empty-state'] && !hasMessages && !isLoading
            ? 'gl-m-auto'
            : 'gl-mt-auto gl-pb-4 gl-pt-6',
        ]"
      >
        <duo-chat-conversation
          v-for="(conversation, index) in conversations"
          :key="`conversation-${index}`"
          :enable-code-insertion="enableCodeInsertion"
          :messages="conversation"
          :show-delimiter="index > 0"
          :with-feedback="withFeedback"
          :is-tool-approval-processing="isToolApprovalProcessing"
          :working-directory="workingDirectory"
          :trusted-urls="trustedUrls"
          :is-binary-feedback-enabled="isBinaryFeedbackEnabled"
          :is-retry-enabled="isRetryEnabled"
          :message-renderers="messageRenderers"
          :selected-alternatives="selectedAlternatives"
          @track-feedback="onTrackFeedback"
          @insert-code-snippet="onInsertCodeSnippet"
          @copy-code-snippet="onCopyCodeSnippet"
          @copy-message="onCopyMessage"
          @get-context-item-content="onGetContextItemContent"
          @approve-tool="onApproveToolCall"
          @deny-tool="onDenyToolCall"
          @open-file-path="onOpenFilePath"
          @question-answered="onQuestionAnswered"
          @retry-message="$emit('retry-message', $event)"
          @select-alternative="$emit('select-alternative', $event)"
        />
        <template v-if="!hasMessages && !isLoading">
          <div key="empty-state-container">
            <slot name="custom-empty-state">
              <div
                key="empty-state-message"
                class="duo-chat-message gl-rounded-bl-none gl-leading-20 gl-text-default gl-break-anywhere"
                data-testid="gl-duo-chat-empty-state"
              >
                <div
                  class="gl-mb-[3.75rem] gl-flex gl-flex-col gl-items-center gl-justify-center gl-gap-3 gl-text-center"
                >
                  <h1 class="gl-my-0 gl-text-[3.5rem]" data-testid="gl-duo-chat-empty-state-emoji">
                    {{ $options.i18n.CHAT_EMPTY_STATE_EMOJI }}
                  </h1>
                  <h2
                    v-if="agentName"
                    class="gl-heading-2 gl-my-0"
                    data-testid="gl-duo-chat-empty-state-greeting"
                  >
                    {{ emptyStateGreeting }}
                  </h2>
                  <h2 class="gl-my-0 gl-text-size-h2" data-testid="gl-duo-chat-empty-state-title">
                    {{ emptyStateMainText }}
                  </h2>
                  <p
                    class="gl-text-base gl-text-subtle"
                    data-testid="gl-duo-chat-empty-state-subtitle"
                  >
                    {{ emptyStateSubText }}
                  </p>
                </div>
                <duo-chat-predefined-prompts
                  key="predefined-prompts"
                  :prompts="predefinedPrompts"
                  @click="sendPredefinedPrompt"
                />
              </div>
            </slot>
          </div>
        </template>
        <duo-chat-loader v-if="isLoading" key="loader" :tool-name="toolName" />
        <div key="anchor" ref="anchor" class="scroll-anchor"></div>
      </transition-group>
    </div>
    <footer
      v-if="!shouldShowThreadList"
      data-testid="chat-footer"
      class="gl-relative gl-z-2 gl-mx-auto gl-w-full gl-max-w-4xl gl-shrink-0 gl-px-3 gl-pb-3"
    >
      <session-pills-bar
        :messages="messages"
        class="gl-mb-2"
        @height-change="onPillsBarHeightChange"
      />
      <slot name="before-footer"></slot>
      <prompt-textarea
        ref="promptTextarea"
        :is-chat-available="isChatAvailable"
        :chat-state="chatState"
        :should-auto-focus-input="false"
        :is-loading="isLoading"
        :last-message="lastMessage"
        :has-footer-controls="hasFooterControls"
        :chat-prompt-placeholder="chatPromptPlaceholder"
        :web-search-enabled="webSearchEnabled"
        @send-chat-prompt="$emit('send-chat-prompt', $event)"
        @chat-cancel="$emit('chat-cancel')"
        @web-search-toggled="$emit('web-search-toggled', $event)"
      >
        <template v-if="glSlots()['agentic-model']" #agentic-model>
          <slot name="agentic-model"></slot>
        </template>
        <template v-if="glSlots()['agentic-switch']" #agentic-switch>
          <slot name="agentic-switch"></slot>
        </template>
      </prompt-textarea>
      <p
        class="gl-mb-0 gl-ml-2 gl-mt-3 gl-text-sm gl-text-subtle"
        :class="{ 'gl-hidden': !hasAssistantMessages }"
        data-testid="chat-disclaimer"
      >
        {{ $options.i18n.CHAT_DISCLAIMER }}
      </p>
      <slot name="footer-controls"></slot>
    </footer>
  </div>
</template>
