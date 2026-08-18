<script>
import { GlButton, GlFormTextarea, GlForm } from '@gitlab/ui';
import {
  CHAT_BASE_COMMANDS,
  MAX_PROMPT_LENGTH,
  PROMPT_LENGTH_WARNING,
} from 'ee/ai/tanuki_bot/constants';
import { isBarrelRollCommand } from 'ee/ai/easter_eggs/barrel_roll';
import { s__, n__, sprintf } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import PromptInputActions from './prompt_input_actions.vue';

const i18n = {
  CHAT_PROMPT_PLACEHOLDER_DEFAULT: s__("DuoAgenticChat|Let's work through this together..."),
  CHAT_SUBMIT_LABEL: s__('DuoAgenticChat|Send chat message.'),
  CHAT_CANCEL_LABEL: s__('DuoAgenticChat|Cancel'),
};

export default {
  name: 'PromptTextarea',
  TEXTAREA_MAX_ROWS: 20,
  components: {
    GlButton,
    GlFormTextarea,
    GlForm,
    PromptInputActions,
  },
  mixins: [glSlotsMixin],
  props: {
    isChatAvailable: {
      type: Boolean,
      required: false,
      default: true,
    },
    chatState: {
      type: Object,
      required: false,
      default: () => ({ isEnabled: true, reason: null }),
    },
    shouldAutoFocusInput: {
      type: Boolean,
      required: false,
      default: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    lastMessage: {
      type: Object,
      required: false,
      default: null,
    },
    hasFooterControls: {
      type: Boolean,
      required: false,
      default: false,
    },
    chatPromptPlaceholder: {
      type: String,
      required: false,
      default: '',
    },
    webSearchEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['send-chat-prompt', 'chat-cancel', 'web-search-toggled'],
  data() {
    return {
      prompt: '',
      canSubmit: true,
      hasValidPrompt: true,
      compositionJustEnded: false,
      hadFocusBeforeSend: false,
      inputHasFocus: false,
      maxPromptLength: MAX_PROMPT_LENGTH,
      promptLengthWarningCount: MAX_PROMPT_LENGTH - PROMPT_LENGTH_WARNING,
    };
  },
  computed: {
    isStreaming() {
      return Boolean(
        (this.lastMessage?.chunks?.length > 0 && !this.lastMessage?.content) ||
        typeof this.lastMessage?.chunkId === 'number',
      );
    },
    caseInsensitivePrompt() {
      return this.prompt.toLowerCase().trim();
    },
    isPromptEmpty() {
      return this.caseInsensitivePrompt.length === 0;
    },
    inputPlaceholder() {
      return this.chatPromptPlaceholder || i18n.CHAT_PROMPT_PLACEHOLDER_DEFAULT;
    },
  },
  watch: {
    isLoading: 'onResponseComplete',
    isStreaming: 'onResponseComplete',
    prompt(newPrompt) {
      this.hasValidPrompt = newPrompt?.length < MAX_PROMPT_LENGTH + 1;
    },
  },
  methods: {
    compositionEnd() {
      this.compositionJustEnded = true;
    },
    cancelPrompt() {
      /**
       * Emitted when user clicks the stop button in the textarea
       */
      this.canSubmit = true;
      this.$emit('chat-cancel');
      this.setPromptAndFocus();
    },
    async sendChatPrompt() {
      if (!this.canSubmit) {
        return;
      }

      if (this.prompt) {
        // Store these before any async operations that might clear the prompt
        this.hadFocusBeforeSend = this.inputHasFocus;
        const trimmedPrompt = this.prompt.trim();
        const lowerCasePrompt = this.prompt.toLowerCase().trim();

        /**
         * Emitted when a new user prompt should be sent out.
         *
         * @param {String} prompt The user prompt to send.
         */
        this.$emit('send-chat-prompt', trimmedPrompt);

        // Always clear the prompt after sending, regardless of the command type
        await this.setPromptAndFocus();
        // Special commands (reset/clear/new) don't trigger a loading state,
        // so avoid disabling the input for them
        if (
          !CHAT_BASE_COMMANDS.includes(lowerCasePrompt) &&
          !isBarrelRollCommand(lowerCasePrompt)
        ) {
          // Wait for all reactive updates to complete before setting canSubmit
          await this.$nextTick();
          this.canSubmit = false;
        }
      }
    },
    onWebSearchToggled(value) {
      this.$emit('web-search-toggled', value);
    },
    // `sendPredefinedPrompt` can be called by the parent component via $refs.
    // eslint-disable-next-line vue/no-unused-properties
    sendPredefinedPrompt(prompt) {
      this.prompt = prompt;
      this.sendChatPrompt();
    },
    focusChatInput() {
      this.$refs.prompt?.focus?.();
    },
    async onResponseComplete() {
      if (this.isLoading || this.isStreaming) return;
      this.canSubmit = true;
      await this.$nextTick();
      this.restoreFocusAfterSend();
    },
    restoreFocusAfterSend() {
      if (!this.hadFocusBeforeSend) return;
      this.hadFocusBeforeSend = false;
      if (!this.isChatAvailable || !this.chatState.isEnabled) return;
      this.focusChatInput();
    },
    shouldSendChatPromptOnEnter(e) {
      const { metaKey, ctrlKey, altKey, shiftKey, isComposing } = e;
      const isModifierKey = metaKey || ctrlKey || altKey || shiftKey;

      return !(isModifierKey || isComposing || this.compositionJustEnded);
    },
    onInputKeyup(e) {
      const { key } = e;

      if (key === 'Enter' && this.shouldSendChatPromptOnEnter(e)) {
        e.preventDefault();
        this.sendChatPrompt();
      }

      this.compositionJustEnded = false;
    },
    async setPromptAndFocus(prompt = '') {
      this.prompt = prompt;
      await this.$nextTick();
      this.focusChatInput();
    },
    handleUndo(event) {
      event.preventDefault();
      document.execCommand?.('undo');
    },
    handleRedo(event) {
      event.preventDefault();
      document.execCommand?.('redo');
    },
    remainingCharacterCountMessage(count) {
      return sprintf(
        n__(
          'DuoAgenticChat|%{count} character remaining.',
          'DuoAgenticChat|%{count} characters remaining.',
          count,
        ),
        { count },
      );
    },
    overLimitCharacterCountMessage(count) {
      return sprintf(
        n__(
          'DuoAgenticChat|%{count} character over limit.',
          'DuoAgenticChat|%{count} characters over limit.',
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
  <gl-form class="gl-relative" data-testid="chat-prompt-form" @submit.stop.prevent="sendChatPrompt">
    <div
      class="agentic-chat-input gl-min-h-8 gl-max-w-full gl-grow gl-flex-col gl-overflow-auto gl-rounded-lg gl-align-top gl-transition-box-shadow forced-colors:gl-border"
    >
      <div
        v-if="glSlots()['agentic-model'] || glSlots()['agentic-switch']"
        class="gl-flex gl-items-center gl-justify-between gl-gap-5 gl-border-0 gl-border-b-1 gl-border-solid gl-border-strong gl-px-4 gl-py-4 forced-colors:gl-border-none"
      >
        <div class="duo-model-switcher gl-min-w-0 gl-max-w-full">
          <slot name="agentic-model"></slot>
        </div>
        <div class="duo-agent-mode-switcher gl-min-w-0 gl-max-w-full gl-shrink-0">
          <slot name="agentic-switch"></slot>
        </div>
      </div>
      <div>
        <gl-form-textarea
          ref="prompt"
          v-model="prompt"
          :disabled="!canSubmit || !isChatAvailable || !chatState.isEnabled"
          data-testid="chat-prompt-input"
          :placeholder="inputPlaceholder"
          :character-count-limit="maxPromptLength"
          :max-rows="$options.TEXTAREA_MAX_ROWS"
          no-resize
          :textarea-classes="[
            'agentic-chat-textarea',
            '!gl-bg-transparent',
            '!gl-shadow-none',
            '!gl-rounded-t-none',
            'gl-w-full',
            'forced-colors:!gl-border-l-0',
            'forced-colors:!gl-border-r-0',
            'forced-colors:!gl-border-b-0',
            '!gl-pr-2',
          ]"
          :autofocus="shouldAutoFocusInput"
          :aria-label="s__('DuoAgenticChat|Chat prompt input')"
          @keydown.enter.exact.native.prevent
          @keydown.ctrl.z.exact="handleUndo"
          @keydown.meta.z.exact="handleUndo"
          @keydown.ctrl.shift.z.exact="handleRedo"
          @keydown.meta.shift.z.exact="handleRedo"
          @keydown.ctrl.y.exact="handleRedo"
          @keydown.meta.y.exact="handleRedo"
          @keyup.native="onInputKeyup"
          @compositionend="compositionEnd"
          @focusin.native="inputHasFocus = true"
          @focusout.native="inputHasFocus = false"
        >
          <template #remaining-character-count-text="{ count }">
            <span
              v-if="count <= promptLengthWarningCount"
              class="gl-absolute gl-right-px gl-mt-3 gl-pr-3 gl-text-sm"
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
              class="gl-absolute gl-bottom-[-1.6rem] gl-right-0 gl-mt-3 gl-pr-3 gl-text-sm"
              :class="{
                'gl-bottom-[-5rem]': hasFooterControls,
                'gl-bottom-[-1.6rem]': !hasFooterControls,
              }"
              >{{ overLimitCharacterCountMessage(count) }}</span
            >
          </template>
        </gl-form-textarea>
      </div>
      <div class="gl-flex gl-items-center gl-justify-end gl-px-3 gl-pb-3">
        <prompt-input-actions
          class="gl-mr-auto"
          :web-search-enabled="webSearchEnabled"
          :disabled="!isChatAvailable || !chatState.isEnabled"
          @update:web-search-enabled="onWebSearchToggled"
        />
        <gl-button
          v-if="canSubmit"
          icon="arrow-up"
          category="primary"
          variant="confirm"
          type="submit"
          :disabled="!isChatAvailable || !chatState.isEnabled || isPromptEmpty || !hasValidPrompt"
          data-testid="chat-prompt-submit-button"
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
</template>
