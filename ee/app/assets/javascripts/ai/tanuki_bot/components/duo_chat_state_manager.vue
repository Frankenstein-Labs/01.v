<script>
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { GlToggle } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import { __, s__ } from '~/locale';
import { renderGFM } from '~/behaviors/markdown/render_gfm';
import { helpPagePath } from '~/helpers/help_page_helper';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { clearDuoChatCommands, generateEventLabelFromText, setAgenticMode } from 'ee/ai/utils';
import { maybeDoBarrelRoll } from 'ee/ai/easter_eggs/barrel_roll';
import { computeTrustedUrls } from 'ee/ai/shared/utils/trusted_urls_utils';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  CLASSIC_CHAT_SHOW_ROUTE,
  CLASSIC_CHAT_HISTORY_ROUTE,
  ROUTE_TO_TAB,
} from 'ee/ai/duo_agents_platform/router/constants';
import { safeRouterPush } from 'ee/ai/duo_agents_platform/utils/router_utils';
import getAiConversationThreads from 'ee/ai/graphql/get_ai_conversation_threads.query.graphql';
import getAiMessagesWithThread from 'ee/ai/graphql/get_ai_messages_with_thread.query.graphql';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import chatWithNamespaceMutation from 'ee/ai/graphql/chat_with_namespace.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import { InternalEvents } from '~/tracking';
import deleteConversationThreadMutation from 'ee/ai/graphql/delete_conversation_thread.mutation.graphql';
import {
  i18n,
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
  DUO_CHAT_VIEWS,
} from 'ee/ai/constants';
import getAiSlashCommands from 'ee/ai/graphql/get_ai_slash_commands.query.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import DuoChatDeleteThreadModal from 'ee/ai/components/duo_chat_delete_thread_modal.vue';
import {
  TANUKI_BOT_TRACKING_EVENT_NAME,
  MESSAGE_TYPES,
  MULTI_THREADED_CONVERSATION_TYPE,
  TYPENAME_AI_CONVERSATION_THREAD,
} from '../constants';
import DuoChatView from './duo_chat_view.vue';
import TanukiBotSubscriptions from './tanuki_bot_subscriptions.vue';

export default {
  name: 'DuoChatStateManager',
  i18n: {
    gitlabChat: s__('DuoChat|GitLab Duo Chat'),
    giveFeedback: s__('DuoChat|Give feedback'),
    source: __('Source'),
    experiment: __('Experiment'),
    askAQuestion: s__('DuoChat|Ask a question about GitLab'),
    exampleQuestion: s__('DuoChat|For example, %{linkStart}what is a fork%{linkEnd}?'),
    whatIsAForkQuestion: s__('DuoChat|What is a fork?'),
    newSlashCommandDescription: s__('DuoChat|New chat conversation.'),
    GENIE_CHAT_LEGAL_GENERATED_BY_AI: i18n.GENIE_CHAT_LEGAL_GENERATED_BY_AI,
  },
  helpPagePath: helpPagePath('policy/development_stages_support', { anchor: 'beta' }),
  components: {
    DuoChatView,
    DuoChatDeleteThreadModal,
    TanukiBotSubscriptions,
    GlToggle,
  },
  mixins: [InternalEvents.mixin()],
  provide() {
    return {
      renderGFM,
      avatarUrl: window.gon?.current_user_avatar_url,
    };
  },
  props: {
    userId: {
      type: String,
      required: true,
    },
    resourceId: {
      type: String,
      required: false,
      default: null,
    },
    projectId: {
      type: String,
      required: false,
      default: null,
    },
    rootNamespaceId: {
      type: String,
      required: false,
      default: null,
    },
    chatTitle: {
      type: String,
      required: false,
      default: null,
    },
    isAgenticAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    mode: {
      type: String,
      required: false,
      default: 'new',
    },
    trustedUrls: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['change-title'],
  apollo: {
    aiConversationThreads: {
      query: getAiConversationThreads,
      context: {
        featureCategory: 'duo_agent_platform',
      },
      update(data) {
        return data?.aiConversationThreads?.nodes || [];
      },
      error(err) {
        this.onError(err);
      },
    },
    aiSlashCommands: {
      query: getAiSlashCommands,
      context: {
        featureCategory: 'duo_agent_platform',
      },
      variables() {
        return {
          url: typeof window !== 'undefined' && window.location ? window.location.href : '',
        };
      },
      update(data) {
        return data?.aiSlashCommands || [];
      },
      error(err) {
        this.onError(err);
      },
    },
    contextPresets: {
      query: getAiChatContextPresets,
      context: {
        featureCategory: 'duo_agent_platform',
      },
      variables() {
        return {
          resourceId: this.resourceId,
          projectId: this.projectId,
          url: typeof window !== 'undefined' && window.location ? window.location.href : '',
          questionCount: 4,
        };
      },
      update(data) {
        return data?.aiChatContextPresets?.questions || [];
      },
      error(err) {
        this.onError(err);
      },
    },
  },
  data() {
    return {
      duoChatGlobalState,
      clientSubscriptionId: uuidv4(),
      toolName: i18n.GITLAB_DUO,
      isResponseTracked: false,
      cancelledRequestIds: [],
      deleteModalVisible: false,
      pendingDeleteThreadId: null,
      isDeletingThread: false,
      completedRequestId: null,
      aiSlashCommands: [],
      aiConversationThreads: [],
      contextPresets: [],
      isWaitingOnPrompt: false,
    };
  },
  computed: {
    ...mapState(['messages']),
    // The open conversation is identified by the numeric id in the route, so
    // it survives a full page reload. Reads expect a GID; the route carries
    // the numeric id.
    activeThread() {
      const id = this.$route?.params?.id;
      return id ? convertToGraphQLId(TYPENAME_AI_CONVERSATION_THREAD, id) : undefined;
    },
    multithreadedView() {
      return this.$route?.name === CLASSIC_CHAT_HISTORY_ROUTE
        ? DUO_CHAT_VIEWS.LIST
        : DUO_CHAT_VIEWS.CHAT;
    },
    duoAgenticModePreference: {
      get() {
        return this.duoChatGlobalState.chatMode === 'agentic';
      },
      set(value) {
        setAgenticMode({ agenticMode: value, saveCookie: true });
      },
    },
    computedResourceId() {
      if (this.hasCommands) {
        return this.duoChatGlobalState.commands[0].resourceId;
      }

      return this.resourceId || this.userId;
    },
    hasCommands() {
      return this.duoChatGlobalState.commands.length > 0;
    },
    predefinedPrompts() {
      return this.contextPresets;
    },
    formattedContextPresets() {
      return this.contextPresets.map((question) => ({
        text: question,
        eventLabel: generateEventLabelFromText(question),
      }));
    },
    computedTrustedUrls() {
      return computeTrustedUrls(this.trustedUrls);
    },
  },
  watch: {
    'duoChatGlobalState.commands': {
      handler() {
        const [command] = this.duoChatGlobalState.commands;
        // openDuoChatWithAgent enqueues commands intended for the agentic manager
        // (autoSend: false, no question). The classic manager must ignore them
        // — sending an empty `question` produces a GraphQL String! violation.
        if (!command || command.autoSend === false || !command.question) return;

        this.onNewChat();
        this.onSendChatPrompt(command.question, command.variables, command.resourceId);
      },
    },
    'duoChatGlobalState.focusChatInput': {
      handler(newVal) {
        if (newVal) {
          this.duoChatGlobalState.focusChatInput = false; // reset global state
          this.focusInput();
        }
      },
      immediate: true,
    },
    mode(newMode) {
      this.switchMode(newMode);
    },
  },
  mounted() {
    this.switchMode(this.mode);
  },
  beforeDestroy() {
    this.isWaitingOnPrompt = false;
  },
  methods: {
    ...mapActions(['addDuoChatMessage', 'setMessages']),
    switchMode(mode) {
      if (mode === 'chat') {
        if (this.activeThread) {
          this.loadActiveThread();
        } else {
          this.onNewChat();
        }
      }
      if (mode === 'new') {
        this.onNewChat();
      }
      if (mode === 'history') {
        this.onBackToList();
        this.$emit('change-title', '');
      }
    },
    shouldStartNewChat(question) {
      return [GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE, GENIE_CHAT_RESET_MESSAGE].includes(
        question,
      );
    },
    findPredefinedPrompt(question) {
      return this.formattedContextPresets.find(({ text }) => text === question);
    },
    navigateToChat(threadId) {
      const id = threadId ? String(getIdFromGraphQLId(threadId)) : undefined;
      // Push when leaving another route or when the target conversation
      // differs, so opening a second thread from the show route still routes.
      if (this.$route?.name !== CLASSIC_CHAT_SHOW_ROUTE || this.$route?.params?.id !== id) {
        safeRouterPush(
          this.$router,
          { name: CLASSIC_CHAT_SHOW_ROUTE, params: { id } },
          { component: 'DuoChat' },
        );
      }
    },
    navigateToHistory() {
      if (this.$route?.name !== CLASSIC_CHAT_HISTORY_ROUTE) {
        safeRouterPush(
          this.$router,
          { name: CLASSIC_CHAT_HISTORY_ROUTE },
          { component: 'DuoChat' },
        );
      }
    },
    async onThreadSelected(e) {
      try {
        const { data } = await this.$apollo.query({
          query: getAiMessagesWithThread,
          variables: { threadId: e.id },
          fetchPolicy: 'network-only',
        });

        if (data?.aiMessages?.nodes?.length > 0) {
          this.setMessages(data.aiMessages.nodes);
        }
      } catch (err) {
        this.onError(err);
      }
      this.navigateToChat(e.id);
    },
    async loadActiveThread() {
      this.onThreadSelected({ id: this.activeThread });
    },
    cleanState() {
      this.setMessages([]);
      this.isWaitingOnPrompt = false;
      this.completedRequestId = null;
      this.cancelledRequestIds = [];
    },
    onNewChat() {
      clearDuoChatCommands();
      this.cleanState();
      // Route to SHOW so the view derives to CHAT. Skip only when already on a
      // chat-tab route AND no thread id is set: a stale id must be dropped, or
      // the next prompt would append to the conversation just closed.
      if (ROUTE_TO_TAB[this.$route?.name] !== 'chat' || this.$route?.params?.id) {
        this.navigateToChat();
      }
    },
    onChatCancel() {
      // pushing last requestId of messages to canceled Request Id's
      this.cancelledRequestIds.push(this.messages[this.messages.length - 1].requestId);
      this.isWaitingOnPrompt = false;
    },
    onMessageReceived(aiCompletionResponse) {
      this.addDuoChatMessage(aiCompletionResponse);
      if (aiCompletionResponse.role.toLowerCase() === MESSAGE_TYPES.TANUKI) {
        this.completedRequestId = aiCompletionResponse.requestId;
        clearDuoChatCommands();
        this.isWaitingOnPrompt = false;
      }
    },
    onMessageStreamReceived(aiCompletionResponse) {
      if (aiCompletionResponse.requestId !== this.completedRequestId) {
        this.addDuoChatMessage(aiCompletionResponse);
      }
    },
    onResponseReceived(requestId) {
      if (this.isResponseTracked) {
        return;
      }

      performance.mark('response-received');
      performance.measure('prompt-to-response', 'prompt-sent', 'response-received');
      const entries = performance.getEntriesByName('prompt-to-response');
      const duration = entries[0]?.duration ?? 0;
      const numericDuration = parseFloat(duration);

      this.trackEvent('ai_response_time', {
        property: requestId,
        value: Number.isFinite(numericDuration) ? parseFloat(numericDuration.toFixed(2)) : 0,
      });

      performance.clearMarks();
      performance.clearMeasures();
      this.isResponseTracked = true;
    },
    onSendChatPrompt(question, variables = {}, resourceId = this.computedResourceId) {
      if (this.shouldStartNewChat(question)) {
        this.onNewChat();
        return;
      }

      if (maybeDoBarrelRoll(question)) return;

      performance.mark('prompt-sent');
      this.completedRequestId = null;
      this.isResponseTracked = false;

      if (!this.isWaitingOnPrompt) {
        this.isWaitingOnPrompt = true;
      }

      const mutationName = this.rootNamespaceId ? chatWithNamespaceMutation : chatMutation;
      const mutationVariables = {
        question,
        resourceId,
        clientSubscriptionId: this.clientSubscriptionId,
        projectId: this.projectId,
        threadId: this.activeThread,
        conversationType: MULTI_THREADED_CONVERSATION_TYPE,
        ...(this.rootNamespaceId && { rootNamespaceId: this.rootNamespaceId }),
        ...variables,
      };

      this.$apollo
        .mutate({
          mutation: mutationName,
          variables: mutationVariables,
          context: {
            headers: {
              'X-GitLab-Interface': 'duo_chat',
              'X-GitLab-Client-Type': 'web_browser',
            },
          },
        })
        .then(({ data: { aiAction = {} } = {} }) => {
          const trackingOptions = {
            property: aiAction.requestId,
            label: this.findPredefinedPrompt(question)?.eventLabel,
          };

          this.trackEvent('submit_gitlab_duo_question', trackingOptions);

          if (aiAction.threadId && !this.activeThread) {
            // Server-assigned id for a brand-new conversation: put it in the
            // route so the thread also survives a reload.
            this.navigateToChat(aiAction.threadId);
          }

          this.addDuoChatMessage({
            ...aiAction,
            content: question,
          });
        })
        .catch((err) => {
          this.addDuoChatMessage({
            content: question,
          });
          this.onError(err);
          this.isWaitingOnPrompt = false;
        });
    },
    onTrackFeedback({ feedbackChoices, didWhat, improveWhat, message } = {}) {
      if (message) {
        const { id, requestId, extras, role, content } = message;
        this.$apollo
          .mutate({
            mutation: duoUserFeedbackMutation,
            variables: {
              input: {
                aiMessageId: id,
                trackingEvent: {
                  category: TANUKI_BOT_TRACKING_EVENT_NAME,
                  action: 'duo_chat',
                  label: 'response_feedback',
                  property: feedbackChoices.join(','),
                  extra: {
                    improveWhat,
                    didWhat,
                    prompt_location: 'after_content',
                  },
                },
              },
            },
          })
          .catch(() => {
            // silent failure because of fire and forget
          });

        this.addDuoChatMessage({
          requestId,
          role,
          content,
          extras: { ...extras, hasFeedback: true },
        });
      }
    },
    onError(err) {
      this.addDuoChatMessage({ errors: [err.toString()] });
    },
    onBackToList() {
      this.navigateToHistory();
      this.setMessages([]);
      this.$apollo.queries.aiConversationThreads.refetch();
    },
    onDeleteThread(threadId) {
      // Confirm before deleting; the request runs from onConfirmDeleteThread.
      this.pendingDeleteThreadId = threadId;
      this.deleteModalVisible = true;
    },
    onConfirmDeleteThread() {
      const threadId = this.pendingDeleteThreadId;
      if (!threadId) {
        return;
      }

      this.isDeletingThread = true;

      this.$apollo
        .mutate({
          mutation: deleteConversationThreadMutation,
          variables: { input: { threadId } },
          update: (cache, { data }) => {
            if (data?.deleteConversationThread?.success) {
              // Remove the thread from the cache instead of refetching the whole
              // list, which would flash the loading state and refresh the view.
              cache.evict({
                id: cache.identify({ __typename: 'AiConversationsThread', id: threadId }),
              });
              cache.gc();
            }
          },
        })
        .then(({ data }) => {
          if (!data?.deleteConversationThread?.success) {
            const errors = data?.deleteConversationThread?.errors || [];
            this.onError(new Error(errors.join(', ')));
          }
        })
        .catch(this.onError)
        .finally(() => {
          this.isDeletingThread = false;
          this.deleteModalVisible = false;
          this.pendingDeleteThreadId = null;
        });
    },
    // `focusInput` can be called by the parent component. Ideally, we would mark this as a public
    // method via Vue's `expose` option. However, doing so would cause several tests to fail in Vue 3
    // because we wrote some assertions directly against the `vm`, which becomes private when `expose`
    // is defined. So we need to _not_ use `expose` and disable vue/no-unused-properties for now.
    async focusInput() {
      const el = this.$refs.duoChat;
      if (el?.focusChatInput) {
        await this.$nextTick();
        el.focusChatInput();
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-min-h-0 gl-w-full gl-grow gl-flex-col">
    <!-- Renderless component for subscriptions -->
    <tanuki-bot-subscriptions
      :user-id="userId"
      :client-subscription-id="clientSubscriptionId"
      :cancelled-request-ids="cancelledRequestIds"
      :active-thread-id="activeThread"
      @message="onMessageReceived"
      @message-stream="onMessageStreamReceived"
      @response-received="onResponseReceived"
      @error="onError"
    />

    <duo-chat-view
      id="duo-chat"
      ref="duoChat"
      class="gl-h-full gl-w-full"
      :thread-list="aiConversationThreads"
      :multi-threaded-view="multithreadedView"
      :is-multithreaded="true"
      :slash-commands="aiSlashCommands"
      :title="chatTitle"
      :messages="messages"
      :is-loading="isWaitingOnPrompt"
      :show-header="false"
      :predefined-prompts="predefinedPrompts"
      :tool-name="toolName"
      :trusted-urls="computedTrustedUrls"
      :canceled-request-ids="cancelledRequestIds"
      @thread-selected="onThreadSelected"
      @new-chat="onNewChat"
      @delete-thread="onDeleteThread"
      @chat-cancel="onChatCancel"
      @send-chat-prompt="onSendChatPrompt"
      @track-feedback="onTrackFeedback"
    >
      <template v-if="isAgenticAvailable" #agentic-switch>
        <gl-toggle v-model="duoAgenticModePreference" label-position="left">
          <template #label>
            <span class="gl-font-normal gl-text-subtle">{{ s__('DuoChat|Agentic') }}</span>
          </template>
        </gl-toggle>
      </template>
    </duo-chat-view>
    <duo-chat-delete-thread-modal
      v-model="deleteModalVisible"
      :loading="isDeletingThread"
      @confirm="onConfirmDeleteThread"
    />
  </div>
</template>
