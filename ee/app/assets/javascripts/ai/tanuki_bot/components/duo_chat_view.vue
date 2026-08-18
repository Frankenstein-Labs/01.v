<script>
import { throttle } from 'lodash-es';

import { GlButton, GlDropdownItem, GlCard, GlFormTextarea, GlForm } from '@gitlab/ui';

import {
  MESSAGE_MODEL_ROLES,
  DuoChatLoader,
  DuoChatPredefinedPrompts,
  DuoChatContextConversation as DuoChatConversation,
  DuoChatThreads,
} from '@gitlab/duo-ui';
import { s__, n__, sprintf } from '~/locale';
import { DUO_CHAT_VIEWS } from 'ee/ai/constants';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import {
  CHAT_RESET_MESSAGE,
  CHAT_CLEAR_MESSAGE,
  CHAT_NEW_MESSAGE,
  CHAT_INCLUDE_MESSAGE,
  MAX_PROMPT_LENGTH,
  PROMPT_LENGTH_WARNING,
} from '../constants';
import DuoChatHeader from '../../duo_agentic_chat/components/duo_chat_header.vue';

export const i18n = {
  CHAT_DEFAULT_TITLE: s__('DuoChat|GitLab Duo Chat'),
  CHAT_HISTORY_TITLE: s__('DuoChat|Chat history'),
  CHAT_DISCLAIMER: s__('DuoChat|Responses may be inaccurate. Verify before use.'),
  CHAT_EMPTY_STATE_EMOJI: '👋',
  CHAT_EMPTY_STATE_TITLE: s__('DuoChat|I am GitLab Duo Chat, your personal AI-powered assistant.'),
  CHAT_EMPTY_STATE_DESCRIPTION: s__('DuoChat|How can I help you today?'),
  CHAT_PROMPT_PLACEHOLDER_DEFAULT: s__("DuoChat|Let's work through this together..."),
  CHAT_PROMPT_PLACEHOLDER_WITH_COMMANDS: s__('DuoChat|Type /help to learn more'),
  CHAT_SUBMIT_LABEL: s__('DuoChat|Send chat message.'),
  CHAT_CANCEL_LABEL: s__('DuoChat|Cancel'),
  CHAT_MODEL_PLACEHOLDER: s__('DuoChat|GitLab Duo Chat'),
  CHAT_DEFAULT_PREDEFINED_PROMPTS: [
    s__('DuoChat|How do I change my password in GitLab?'),
    s__('DuoChat|How do I fork a project?'),
    s__('DuoChat|How do I clone a repository?'),
    s__('DuoChat|How do I create a template?'),
  ],
};

const isMessage = (item) => Boolean(item) && item?.role;
const isSlashCommand = (command) => Boolean(command) && command?.name && command.description;

const itemsValidator = (items) => items.every(isMessage);
const slashCommandsValidator = (commands) => commands.every(isSlashCommand);

const isThread = (thread) =>
  typeof thread === 'object' &&
  typeof thread.id === 'string' &&
  typeof thread.lastUpdatedAt === 'string' &&
  typeof thread.createdAt === 'string' &&
  typeof thread.conversationType === 'string' &&
  (thread.title === null || typeof thread.title === 'string');

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
  name: 'DuoChatView',
  components: {
    GlButton,
    GlFormTextarea,
    GlForm,
    DuoChatLoader,
    DuoChatPredefinedPrompts,
    DuoChatConversation,
    DuoChatHeader,
    DuoChatThreads,
    GlCard,
    GlDropdownItem,
  },
  mixins: [glSlotsMixin],
  provide() {
    return {
      markdownClass: 'md',
    };
  },
  props: {
    /**
     * The title of the chat/feature.
     */
    title: {
      type: String,
      required: false,
      default: i18n.CHAT_DEFAULT_TITLE,
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
     * Array of RequestIds that have been canceled.
     */
    canceledRequestIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    /**
     * Array of messages to display in the chat.
     */
    threadList: {
      type: Array,
      required: false,
      default: () => [],
      validator: threadListValidator,
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
     * Array of slash commands to display in the chat.
     */
    slashCommands: {
      type: Array,
      required: false,
      default: () => [],
      validator: slashCommandsValidator,
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
    /*
     * The preferred locale for the chat interface.
     * Follows BCP 47 language tag format (e.g., 'en-US', 'fr-FR', 'es-ES').
     */
    preferredLocale: {
      type: Array,
      required: false,
      default: () => ['en-US', 'en'],
      validator: localeValidator,
    },
  },
  emits: [
    'chat-cancel',
    'chat-hidden',
    'chat-slash',
    'copy-code-snippet',
    'copy-message',
    'delete-thread',
    'get-context-item-content',
    'insert-code-snippet',
    'new-chat',
    'open-file-path',
    'send-chat-prompt',
    'thread-selected',
    'track-feedback',
  ],
  data() {
    return {
      prompt: '',
      scrolledToBottom: true,
      activeCommandIndex: 0,
      displaySubmitButton: true,
      compositionJustEnded: false,
      contextItemsMenuIsOpen: false,
      contextItemMenuRef: null,
      currentView: this.multiThreadedView,
      maxPromptLength: MAX_PROMPT_LENGTH,
      promptLengthWarningCount: MAX_PROMPT_LENGTH - PROMPT_LENGTH_WARNING,
    };
  },
  computed: {
    shouldShowThreadList() {
      return this.isMultithreaded && this.currentView === DUO_CHAT_VIEWS.LIST;
    },
    withSlashCommands() {
      return this.slashCommands.length > 0;
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
            acc[acc.length - 1].push(message);
          }
          return acc;
        },
        [[]],
      );
    },
    lastMessage() {
      return this.messages?.[this.messages.length - 1];
    },
    caseInsensitivePrompt() {
      return this.prompt.toLowerCase().trim();
    },
    isPromptEmpty() {
      return this.caseInsensitivePrompt.length === 0;
    },
    isStreaming() {
      if (this.canceledRequestIds.includes(this.lastMessage?.requestId)) {
        return false;
      }
      return Boolean(
        (this.lastMessage?.chunks?.length > 0 && !this.lastMessage?.content) ||
        typeof this.lastMessage?.chunkId === 'number',
      );
    },
    filteredSlashCommands() {
      return this.slashCommands
        .filter((c) => c.name.toLowerCase().startsWith(this.caseInsensitivePrompt))
        .filter((c) => {
          if (c.name === CHAT_INCLUDE_MESSAGE) {
            return this.hasContextItemSelectionMenu;
          }
          return true;
        });
    },
    shouldShowSlashCommands() {
      if (!this.withSlashCommands || this.contextItemsMenuIsOpen) return false;
      const startsWithSlash = this.caseInsensitivePrompt.startsWith('/');
      const startsWithSlashCommand = this.slashCommands.some((c) =>
        this.caseInsensitivePrompt.startsWith(c.name),
      );
      return startsWithSlash && this.filteredSlashCommands.length && !startsWithSlashCommand;
    },
    shouldShowContextItemSelectionMenu() {
      if (!this.hasContextItemSelectionMenu) {
        return false;
      }

      const isSlash = this.caseInsensitivePrompt === '/';
      if (!this.caseInsensitivePrompt || isSlash) {
        // if user has removed entire command (or whole command except for '/') we should close context item menu and allow slash command menu to show again
        return false;
      }

      return CHAT_INCLUDE_MESSAGE.startsWith(this.caseInsensitivePrompt);
    },
    inputPlaceholder() {
      if (this.chatPromptPlaceholder) {
        return this.chatPromptPlaceholder;
      }

      return this.withSlashCommands
        ? i18n.CHAT_PROMPT_PLACEHOLDER_WITH_COMMANDS
        : i18n.CHAT_PROMPT_PLACEHOLDER_DEFAULT;
    },
    hasContextItemSelectionMenu() {
      return Boolean(this.contextItemMenuRef);
    },
    hasFooterControls() {
      return (
        this.glSlots()?.['footer-controls'] &&
        typeof this.glSlots()['footer-controls'] === 'function' &&
        this.glSlots()['footer-controls']()
      );
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
    isLoading(newVal) {
      if (!newVal && !this.isStreaming) {
        this.displaySubmitButton = true; // Re-enable submit button when loading stops
      }
    },
    isStreaming(newVal) {
      if (!newVal && !this.isLoading) {
        this.displaySubmitButton = true; // Re-enable submit button when streaming stops
      }
    },
    lastMessage(newMessage) {
      if (this.scrolledToBottom || newMessage?.role.toLowerCase() === MESSAGE_MODEL_ROLES.user) {
        // only scroll to bottom on new message if the user hasn't explicitly scrolled up to view an earlier message
        // or if the user has just submitted a new message
        this.scrollToBottom();
      }
    },
    shouldShowSlashCommands(shouldShow) {
      if (shouldShow) {
        this.onShowSlashCommands();
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
    onNewChat() {
      this.$emit('new-chat');

      this.$nextTick(() => {
        this.focusChatInput();
      });
    },
    compositionEnd() {
      this.compositionJustEnded = true;
    },
    hideChat() {
      /**
       * Emitted when clicking the cross in the title and the chat gets closed.
       */
      this.$emit('chat-hidden');
    },
    cancelPrompt() {
      /**
       * Emitted when user clicks the stop button in the textarea
       */

      this.displaySubmitButton = true;
      this.$emit('chat-cancel');
      this.setPromptAndFocus();
    },
    sendChatPrompt() {
      if (!this.displaySubmitButton || this.contextItemsMenuIsOpen) {
        return;
      }
      if (this.prompt) {
        if (
          this.caseInsensitivePrompt.startsWith(CHAT_INCLUDE_MESSAGE) &&
          this.hasContextItemSelectionMenu
        ) {
          this.contextItemsMenuIsOpen = true;
          return;
        }

        if (
          ![CHAT_RESET_MESSAGE, CHAT_CLEAR_MESSAGE, CHAT_NEW_MESSAGE].includes(
            this.caseInsensitivePrompt,
          )
        ) {
          this.displaySubmitButton = false;
        }

        /**
         * Emitted when a new user prompt should be sent out.
         *
         * @param {String} prompt The user prompt to send.
         */
        this.$emit('send-chat-prompt', this.prompt.trim());

        this.setPromptAndFocus();
      }
    },
    sendPredefinedPrompt(prompt) {
      this.contextItemsMenuIsOpen = false;
      this.prompt = prompt;
      this.sendChatPrompt();
    },
    handleScrolling(event) {
      const { scrollTop, offsetHeight, scrollHeight } = event.target;
      this.scrolledToBottom = scrollTop + offsetHeight >= scrollHeight;
    },
    async scrollToBottom() {
      await this.$nextTick();

      this.$refs.anchor?.scrollIntoView?.();
    },
    focusChatInput() {
      // This method is also called directly by consumers of this component
      // https://gitlab.com/gitlab-org/gitlab-vscode-extension/-/blob/dae2d4669ab4da327921492a2962beae8a05c290/webviews/vue2/gitlab_duo_chat/src/App.vue#L109
      this.$refs.prompt?.$el?.querySelector?.('textarea')?.focus();
    },
    onTrackFeedback(event) {
      /**
       * Notify listeners about the feedback form submission on a response message.
       * @param {*} event An event, containing the feedback choices and the extended feedback text.
       */
      this.$emit('track-feedback', event);
    },
    onShowSlashCommands() {
      /**
       * Emitted when user opens the slash commands menu
       */
      this.$emit('chat-slash');
    },
    sendChatPromptOnEnter(e) {
      const { metaKey, ctrlKey, altKey, shiftKey, isComposing } = e;
      const isModifierKey = metaKey || ctrlKey || altKey || shiftKey;

      return !(isModifierKey || isComposing || this.compositionJustEnded);
    },
    onInputKeyup(e) {
      const { key } = e;

      if (this.contextItemsMenuIsOpen) {
        if (!this.shouldShowContextItemSelectionMenu) {
          this.contextItemsMenuIsOpen = false;
        }
        this.contextItemMenuRef?.handleKeyUp(e);
        return;
      }
      if (this.caseInsensitivePrompt === CHAT_INCLUDE_MESSAGE) {
        this.contextItemsMenuIsOpen = true;
        return;
      }

      if (this.shouldShowSlashCommands) {
        e.preventDefault();

        if (key === 'Enter') {
          this.selectSlashCommand(this.activeCommandIndex);
        } else if (key === 'ArrowUp') {
          this.prevCommand();
        } else if (key === 'ArrowDown') {
          this.nextCommand();
        } else {
          this.activeCommandIndex = 0;
        }
      } else if (key === 'Enter' && this.sendChatPromptOnEnter(e)) {
        e.preventDefault();

        this.sendChatPrompt();
      }

      this.compositionJustEnded = false;
    },
    prevCommand() {
      this.activeCommandIndex -= 1;
      this.wrapCommandIndex();
    },
    nextCommand() {
      this.activeCommandIndex += 1;
      this.wrapCommandIndex();
    },
    wrapCommandIndex() {
      if (this.activeCommandIndex < 0) {
        this.activeCommandIndex = this.filteredSlashCommands.length - 1;
      } else if (this.activeCommandIndex >= this.filteredSlashCommands.length) {
        this.activeCommandIndex = 0;
      }
    },
    async setPromptAndFocus(prompt = '') {
      this.prompt = prompt;
      await this.$nextTick();
      this.focusChatInput();
    },
    selectSlashCommand(index) {
      const command = this.filteredSlashCommands[index];
      if (command.shouldSubmit) {
        this.prompt = command.name;
        this.sendChatPrompt();
      } else {
        this.setPromptAndFocus(`${command.name} `);

        if (command.name === CHAT_INCLUDE_MESSAGE && this.hasContextItemSelectionMenu) {
          this.contextItemsMenuIsOpen = true;
        }
      }
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
    closeContextItemsMenuOpen() {
      this.contextItemsMenuIsOpen = false;
      this.setPromptAndFocus();
    },
    setContextItemsMenuRef(ref) {
      this.contextItemMenuRef = ref;
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
    onOpenFilePath(filePath) {
      /**
       * Emitted when a file path link is clicked in a chat message.
       * @param {String} filePath The file path to open
       */
      this.$emit('open-file-path', filePath);
    },
    handleUndo(event) {
      event.preventDefault();
      document.execCommand('undo');
    },
    handleRedo(event) {
      event.preventDefault();
      document.execCommand('redo');
    },
    remainingCharacterCountMessage(count) {
      return sprintf(
        n__(
          'DuoChat|%{count} character remaining.',
          'DuoChat|%{count} characters remaining.',
          count,
        ),
        { count },
      );
    },
    overLimitCharacterCountMessage(count) {
      return sprintf(
        n__(
          'DuoChat|%{count} character over limit.',
          'DuoChat|%{count} characters over limit.',
          count,
        ),
        { count },
      );
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
    <duo-chat-header
      v-if="showHeader"
      ref="header"
      :title="isMultithreaded && currentView === 'list' ? $options.i18n.CHAT_HISTORY_TITLE : title"
      :current-view="currentView"
    >
      <template v-if="glSlots().subheader" #subheader>
        <slot name="subheader"></slot>
      </template>
    </duo-chat-header>

    <div
      class="panel-content-inner gl-flex gl-flex-grow gl-flex-col gl-overscroll-contain gl-bg-inherit"
      data-testid="chat-history"
      @scroll="handleScrollingThrottled"
    >
      <duo-chat-threads
        v-if="shouldShowThreadList"
        class="gl-mx-auto gl-w-full gl-max-w-4xl"
        :threads="threadList"
        :preferred-locale="preferredLocale"
        @new-chat="onNewChat"
        @select-thread="onSelectThread"
        @delete-thread="onDeleteThread"
        @close="hideChat"
      />
      <transition-group
        v-else
        mode="out-in"
        tag="section"
        name="message"
        class="duo-chat-history gl-mx-auto gl-mt-auto gl-w-full gl-max-w-4xl gl-px-4 gl-pb-4 gl-pt-6"
      >
        <duo-chat-conversation
          v-for="(conversation, index) in conversations"
          :key="`conversation-${index}`"
          :enable-code-insertion="enableCodeInsertion"
          :messages="conversation"
          :show-delimiter="index > 0"
          :trusted-urls="trustedUrls"
          @track-feedback="onTrackFeedback"
          @insert-code-snippet="onInsertCodeSnippet"
          @copy-code-snippet="onCopyCodeSnippet"
          @copy-message="onCopyMessage"
          @get-context-item-content="onGetContextItemContent"
          @open-file-path="onOpenFilePath"
        />
        <template v-if="!hasMessages && !isLoading">
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
              <h2 class="gl-my-0 gl-text-size-h2" data-testid="gl-duo-chat-empty-state-title">
                {{ emptyStateMainText }}
              </h2>
              <p class="gl-text-base gl-text-subtle" data-testid="gl-duo-chat-empty-state-subtitle">
                {{ emptyStateSubText }}
              </p>
            </div>
            <duo-chat-predefined-prompts
              key="predefined-prompts"
              :prompts="predefinedPrompts"
              @click="sendPredefinedPrompt"
            />
          </div>
        </template>
        <duo-chat-loader v-if="isLoading" key="loader" :tool-name="toolName" />
        <div key="anchor" ref="anchor" class="scroll-anchor"></div>
      </transition-group>
    </div>
    <footer
      v-if="isChatAvailable && !shouldShowThreadList"
      data-testid="chat-footer"
      class="gl-relative gl-z-2 gl-mx-auto gl-w-full gl-max-w-4xl gl-shrink-0 gl-px-3 gl-pb-3"
    >
      <p
        class="gl-mb-3 gl-ml-2 gl-text-sm gl-text-subtle"
        :class="{ 'gl-hidden': !hasAssistantMessages }"
        data-testid="chat-disclaimer"
      >
        {{ $options.i18n.CHAT_DISCLAIMER }}
      </p>
      <gl-form data-testid="chat-prompt-form" @submit.stop.prevent="sendChatPrompt">
        <div class="gl-relative gl-max-w-full">
          <!--
              @slot For integrating `<gl-context-items-menu>` component if pinned-context should be available. The following scopedSlot properties are provided: `isOpen`, `onClose`, `setRef`, `focusPrompt`, which should be passed to the `<gl-context-items-menu>` component when rendering, e.g. `<template #context-items-menu="{ isOpen, onClose, setRef, focusPrompt }">` `<duo-chat-context-item-menu :ref="setRef" :open="isOpen" @close="onClose" @focus-prompt="focusPrompt" ...`
            -->
          <slot
            name="context-items-menu"
            :is-open="contextItemsMenuIsOpen"
            :on-close="closeContextItemsMenuOpen"
            :set-ref="setContextItemsMenuRef"
            :focus-prompt="focusChatInput"
          ></slot>
        </div>

        <div
          class="duo-chat-input gl-relative gl-min-h-8 gl-max-w-full gl-grow gl-flex-col gl-rounded-lg gl-align-top forced-colors:gl-border"
        >
          <div
            class="gl-flex gl-justify-between gl-border-0 gl-border-b-1 gl-border-solid gl-border-strong gl-px-4 gl-py-4 forced-colors:gl-border-none"
          >
            <div>{{ $options.i18n.CHAT_MODEL_PLACEHOLDER }}</div>
            <div><slot name="agentic-switch"></slot></div>
          </div>
          <div
            class="duo-chat-input-wrap gl-relative gl-flex gl-grow gl-flex-col"
            :data-value="prompt"
          >
            <gl-card
              v-if="shouldShowSlashCommands"
              ref="commands"
              class="slash-commands !gl-absolute gl-w-full -gl-translate-y-full gl-list-none gl-pl-0 gl-shadow-md"
              body-class="!gl-p-2"
            >
              <gl-dropdown-item
                v-for="(command, index) in filteredSlashCommands"
                :key="command.name"
                :class="{ 'active-command': index === activeCommandIndex }"
                @mouseenter.native="activeCommandIndex = index"
                @click="selectSlashCommand(index)"
              >
                <span class="gl-flex gl-justify-between">
                  <span class="gl-block">{{ command.name }}</span>
                  <small class="gl-pl-3 gl-text-right gl-italic gl-text-subtle">{{
                    command.description
                  }}</small>
                </span>
              </gl-dropdown-item>
            </gl-card>

            <gl-form-textarea
              ref="prompt"
              v-model="prompt"
              class="gl-absolute !gl-h-full !gl-w-full"
              data-testid="chat-prompt-input"
              :textarea-classes="[
                'duo-chat-textarea',
                '!gl-h-full',
                '!gl-bg-transparent',
                '!gl-py-4',
                '!gl-shadow-none',
                '!gl-rounded-t-none',
                'forced-colors:!gl-border-l-0',
                'forced-colors:!gl-border-r-0',
                'forced-colors:!gl-border-b-0',
                { 'gl-truncate': !prompt },
              ]"
              :placeholder="inputPlaceholder"
              :character-count-limit="maxPromptLength"
              :autofocus="false"
              @keydown.enter.exact.native.prevent
              @keydown.ctrl.z.exact="handleUndo"
              @keydown.meta.z.exact="handleUndo"
              @keydown.ctrl.shift.z="handleRedo"
              @keydown.meta.shift.z="handleRedo"
              @keydown.ctrl.y="handleRedo"
              @keydown.meta.y="handleRedo"
              @keyup.native="onInputKeyup"
              @compositionend="compositionEnd"
            >
              <template #remaining-character-count-text="{ count }">
                <span
                  v-if="count <= promptLengthWarningCount"
                  class="gl-absolute gl-bottom-0 gl-bottom-[-1.6rem] gl-right-0 gl-pr-3 gl-text-sm"
                  :class="{
                    'gl-bottom-[-5rem]': hasFooterControls,
                    'gl-bottom-[-1.6rem]': !hasFooterControls,
                  }"
                >
                  {{ remainingCharacterCountMessage(count) }}
                </span>
              </template>
              <template #character-count-over-limit-text="{ count }">
                <span
                  class="gl-absolute gl-bottom-[-1.6rem] gl-right-px gl-pr-3 gl-text-sm"
                  :class="{
                    'gl-bottom-[-5rem]': hasFooterControls,
                    'gl-bottom-[-1.6rem]': !hasFooterControls,
                  }"
                  >{{ overLimitCharacterCountMessage(count) }}</span
                >
              </template>
            </gl-form-textarea>
          </div>
          <div class="gl-absolute gl-bottom-0 gl-right-0 gl-px-3 gl-pb-3">
            <gl-button
              v-if="displaySubmitButton"
              icon="arrow-up"
              category="primary"
              variant="confirm"
              type="submit"
              data-testid="chat-prompt-submit-button"
              :disabled="isPromptEmpty"
              :aria-label="$options.i18n.CHAT_SUBMIT_LABEL"
            />
            <gl-button
              v-else
              icon="stop"
              category="primary"
              variant="default"
              data-testid="chat-prompt-cancel-button"
              :aria-label="$options.i18n.CHAT_CANCEL_LABEL"
              @click="cancelPrompt"
            />
          </div>
        </div>
      </gl-form>
      <slot name="footer-controls"></slot>
    </footer>
  </div>
</template>
