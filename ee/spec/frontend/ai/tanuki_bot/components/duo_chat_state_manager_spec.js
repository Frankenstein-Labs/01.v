import Vue, { nextTick } from 'vue';
import { v4 as uuidv4 } from 'uuid';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { GlToggle } from '@gitlab/ui';
import { sendDuoChatCommand, setAgenticMode } from 'ee/ai/utils';
import DuoChatStateManager from 'ee/ai/tanuki_bot/components/duo_chat_state_manager.vue';
import DuoChatView from 'ee/ai/tanuki_bot/components/duo_chat_view.vue';
import DuoChatDeleteThreadModal from 'ee/ai/components/duo_chat_delete_thread_modal.vue';
import TanukiBotSubscriptions from 'ee/ai/tanuki_bot/components/tanuki_bot_subscriptions.vue';
import {
  GENIE_CHAT_RESET_MESSAGE,
  GENIE_CHAT_CLEAR_MESSAGE,
  GENIE_CHAT_NEW_MESSAGE,
} from 'ee/ai/constants';
import {
  CLASSIC_CHAT_SHOW_ROUTE,
  CLASSIC_CHAT_HISTORY_ROUTE,
  CLASSIC_CHAT_NEW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import chatWithNamespaceMutation from 'ee/ai/graphql/chat_with_namespace.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import deleteConversationThreadMutation from 'ee/ai/graphql/delete_conversation_thread.mutation.graphql';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import getAiMessagesWithThread from 'ee/ai/graphql/get_ai_messages_with_thread.query.graphql';
import getAiConversationThreads from 'ee/ai/graphql/get_ai_conversation_threads.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { getMarkdown } from '~/rest_api';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/state';
import getAiSlashCommands from 'ee/ai/graphql/get_ai_slash_commands.query.graphql';
import getAiChatContextPresets from 'ee/ai/graphql/get_ai_chat_context_presets.query.graphql';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

import {
  MOCK_USER_MESSAGE,
  MOCK_USER_ID,
  MOCK_RESOURCE_ID,
  MOCK_CHUNK_MESSAGE,
  MOCK_TANUKI_BOT_MUTATATION_RES,
  GENERATE_MOCK_TANUKI_RES,
  MOCK_CHAT_CACHED_MESSAGES_RES,
  MOCK_SLASH_COMMANDS,
  MOCK_TANUKI_MESSAGE,
  MOCK_THREADS,
  MOCK_THREADS_RESPONSE,
  MOCK_CONTEXT_PRESETS_RESPONSE,
} from '../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/rest_api');
jest.mock('uuid');

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
  setCookie: jest.fn(),
}));

jest.mock('ee/ai/utils', () => {
  const actualUtils = jest.requireActual('ee/ai/utils');

  return {
    __esModule: true,
    ...actualUtils,
    setAgenticMode: jest.fn(),
  };
});

let wrapper;

const UUIDMOCK = '123';

const actionSpies = {
  addDuoChatMessage: jest.fn(),
  setMessages: jest.fn(),
};

const chatMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
const chatWithNamespaceMutationHandlerMock = jest
  .fn()
  .mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
const duoUserFeedbackMutationHandlerMock = jest.fn().mockResolvedValue({});
const deleteConversationThreadMutationHandlerMock = jest.fn().mockResolvedValue({});
const queryHandlerMock = jest.fn().mockResolvedValue(MOCK_CHAT_CACHED_MESSAGES_RES);
const threadQueryHandlerMock = jest.fn().mockResolvedValue({});
const conversationThreadsQueryHandlerMock = jest.fn().mockResolvedValue({});
const slashCommandsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_SLASH_COMMANDS);
const contextPresetsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_CONTEXT_PRESETS_RESPONSE);
const { bindInternalEventDocument } = useMockInternalEventsTracking();
const docsUrlHost = 'docs.gitlab.com';
const findSubscriptions = () => wrapper.findComponent(TanukiBotSubscriptions);

let mockRouter;
let mockRoute;
let routePath;

// The view now derives from $route.name, so tests seed a route rather than a
// view. Known legacy routePath values map to their route name; routeName wins.
const ROUTE_PATH_TO_NAME = {
  '/chat': CLASSIC_CHAT_SHOW_ROUTE,
  '/new': CLASSIC_CHAT_NEW_ROUTE,
  '/history': CLASSIC_CHAT_HISTORY_ROUTE,
};

const MOCK_DEFAULT_PROPS = {
  userId: MOCK_USER_ID,
  resourceId: MOCK_RESOURCE_ID,
  trustedUrls: [],
};

const createComponent = ({
  initialState = {},
  propsData = MOCK_DEFAULT_PROPS,
  data = {},
  stubs = {},
  routePath: customRoutePath = '/chat',
  routeName = ROUTE_PATH_TO_NAME[customRoutePath] ?? CLASSIC_CHAT_SHOW_ROUTE,
  routeParams = {},
} = {}) => {
  routePath = customRoutePath;
  // Mirror real Vue Router: pushing a named location updates the reactive
  // $route so the route-derived multithreadedView/activeThread computeds
  // re-evaluate.
  // eslint-disable-next-line no-restricted-properties
  mockRoute = Vue.observable({ name: routeName, path: routePath, params: routeParams });
  mockRouter = {
    push: jest.fn((location) => {
      if (location?.name) {
        mockRoute.name = location.name;
        mockRoute.params = location.params ?? {};
      }
    }),
  };

  const store = new Vuex.Store({
    actions: actionSpies,
    state: {
      ...initialState,
    },
  });

  const apolloProvider = createMockApollo([
    [chatMutation, chatMutationHandlerMock],
    [chatWithNamespaceMutation, chatWithNamespaceMutationHandlerMock],
    [duoUserFeedbackMutation, duoUserFeedbackMutationHandlerMock],
    [deleteConversationThreadMutation, deleteConversationThreadMutationHandlerMock],
    [getAiMessages, queryHandlerMock],
    [getAiMessagesWithThread, threadQueryHandlerMock],
    [getAiConversationThreads, conversationThreadsQueryHandlerMock],
    [getAiSlashCommands, slashCommandsQueryHandlerMock],
    [getAiChatContextPresets, contextPresetsQueryHandlerMock],
  ]);

  wrapper = shallowMountExtended(DuoChatStateManager, {
    store,
    apolloProvider,
    propsData,
    stubs,
    data() {
      return data;
    },
    mocks: {
      $route: mockRoute,
      $router: mockRouter,
    },
  });
};

const findDuoChat = () => wrapper.findComponent(DuoChatView);
const findDeleteThreadModal = () => wrapper.findComponent(DuoChatDeleteThreadModal);

beforeEach(() => {
  uuidv4.mockImplementation(() => UUIDMOCK);
  getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));
});

afterEach(() => {
  jest.clearAllMocks();
  duoChatGlobalState.commands = [];
});

it('generates unique `clientSubscriptionId` using v4', () => {
  createComponent();
  expect(uuidv4).toHaveBeenCalled();
  expect(wrapper.vm.clientSubscriptionId).toBe('123');
});

describe('rendering', () => {
  describe('when Duo Chat is shown', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the DuoChat component', () => {
      expect(findDuoChat().exists()).toBe(true);
    });

    it('calls the slash commands GraphQL query when component loads', () => {
      expect(slashCommandsQueryHandlerMock).toHaveBeenCalledWith({
        url: 'http://test.host/',
      });
    });

    it('calls the context presets GraphQL query when component loads', () => {
      expect(contextPresetsQueryHandlerMock).toHaveBeenCalledWith({
        resourceId: MOCK_RESOURCE_ID,
        projectId: null,
        url: 'http://test.host/',
        questionCount: 4,
      });
    });

    it('passes the correct slash commands to the DuoChat component', async () => {
      await waitForPromises();

      const duoChat = findDuoChat();

      expect(duoChat.props('slashCommands')).toEqual([
        {
          description: 'New chat conversation.',
          name: '/new',
          shouldSubmit: false,
        },
        {
          description: 'Learn what Duo Chat can do.',
          name: '/help',
          shouldSubmit: true,
        },
      ]);
    });
  });
});

describe('contextPresets', () => {
  beforeEach(() => {
    createComponent();
  });

  it('passes context presets to DuoChat component as predefinedPrompts', async () => {
    await waitForPromises();

    expect(findDuoChat().props('predefinedPrompts')).toEqual(
      MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions,
    );
  });
});

describe('when new commands are added to the global state', () => {
  let originalRequestIdleCallback;

  beforeEach(async () => {
    originalRequestIdleCallback = window.requestIdleCallback;
    window.requestIdleCallback = (callback) => callback();

    createComponent();
    await waitForPromises();
    performance.mark = jest.fn();
  });

  afterEach(() => {
    duoChatGlobalState.commands = [];
    window.requestIdleCallback = originalRequestIdleCallback;
  });

  it('resets chat', async () => {
    const onNewChatSpy = jest.spyOn(wrapper.vm, 'onNewChat');
    sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
    await nextTick();
    expect(onNewChatSpy).toHaveBeenCalled();
  });

  it('calls the chat mutation', async () => {
    sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
    await waitForPromises();
    expect(chatMutationHandlerMock).toHaveBeenCalledTimes(1);
  });

  it('uses the command resourceId', async () => {
    sendDuoChatCommand({ question: '/troubleshoot', resourceId: 'command::1' });
    await waitForPromises();

    expect(chatMutationHandlerMock).toHaveBeenCalledWith({
      clientSubscriptionId: '123',
      question: '/troubleshoot',
      resourceId: 'command::1',
      projectId: null,
      conversationType: 'DUO_CHAT',
      threadId: undefined,
    });
  });

  it('ignores commands with autoSend: false (enqueued by openDuoChatWithAgent)', async () => {
    duoChatGlobalState.commands = [
      { resourceId: 'command::1', agent: { name: 'Planner' }, autoSend: false },
    ];
    await waitForPromises();

    expect(chatMutationHandlerMock).not.toHaveBeenCalled();
  });

  it('ignores commands without a question', async () => {
    duoChatGlobalState.commands = [{ resourceId: 'command::1' }];
    await waitForPromises();

    expect(chatMutationHandlerMock).not.toHaveBeenCalled();
  });
});

describe('events handling', () => {
  beforeEach(() => {
    createComponent();
  });

  describe('@send-chat-prompt', () => {
    beforeEach(() => {
      performance.mark = jest.fn();
    });

    it.each([GENIE_CHAT_NEW_MESSAGE, GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
      'resets chat state when "%s" command is sent',
      async (command) => {
        createComponent();
        findDuoChat().vm.$emit('send-chat-prompt', command);
        await nextTick();

        const duoChat = findDuoChat();
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
        expect(duoChat.props('multiThreadedView')).toBe('chat');
        expect(duoChat.props('canceledRequestIds')).toEqual([]);
        expect(chatMutationHandlerMock).not.toHaveBeenCalled();
      },
    );

    it('does set loading to `true` unless a new chat is requested', async () => {
      createComponent();
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await nextTick();
      expect(findDuoChat().props('isLoading')).toBe(true);
    });

    it('starts the performance measurement when sending a prompt', () => {
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      expect(performance.mark).toHaveBeenCalledWith('prompt-sent');
    });

    it('calls the chat mutation with projectId when available', async () => {
      createComponent({
        propsData: { userId: MOCK_USER_ID, resourceId: null, projectId: 'project-123' },
      });

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

      await nextTick();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: MOCK_USER_MESSAGE.content,
        resourceId: MOCK_USER_ID,
        projectId: 'project-123',
        conversationType: 'DUO_CHAT',
        threadId: undefined,
      });
    });

    it('calls the chat mutation without projectId if it is not provided', async () => {
      createComponent({
        propsData: { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID, projectId: null },
      });

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

      await nextTick();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: MOCK_USER_MESSAGE.content,
        resourceId: MOCK_RESOURCE_ID,
        projectId: null,
        conversationType: 'DUO_CHAT',
        threadId: undefined,
      });
    });

    it('sends the chat mutation with correct headers', async () => {
      createComponent();

      // Spy on the Apollo mutate method to capture the full mutation options
      const mutateSpy = jest.spyOn(wrapper.vm.$apollo, 'mutate');

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

      await nextTick();

      expect(mutateSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          mutation: chatMutation,
          variables: expect.any(Object),
          context: {
            headers: {
              'X-GitLab-Interface': 'duo_chat',
              'X-GitLab-Client-Type': 'web_browser',
            },
          },
        }),
      );
    });

    describe.each`
      resourceId          | expectedResourceId
      ${MOCK_RESOURCE_ID} | ${MOCK_RESOURCE_ID}
      ${null}             | ${MOCK_USER_ID}
    `(`with resourceId = $resourceId`, ({ resourceId, expectedResourceId }) => {
      it('calls correct GraphQL mutation with fallback to userId when input is submitted', async () => {
        createComponent({
          propsData: { userId: MOCK_USER_ID, resourceId },
        });
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          resourceId: expectedResourceId,
          question: MOCK_USER_MESSAGE.content,
          clientSubscriptionId: '123',
          projectId: null,
          conversationType: 'DUO_CHAT',
          threadId: undefined,
        });
      });
    });

    describe('tracking on mutation', () => {
      const expectedCategory = undefined;
      const expectedAction = 'submit_gitlab_duo_question';
      const defaultTrackingOption = {
        property: MOCK_TANUKI_BOT_MUTATATION_RES.data.aiAction.requestId,
      };

      beforeEach(async () => {
        createComponent();
        await waitForPromises();
      });

      it('tracks the submission for prompts by default', async () => {
        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await waitForPromises();
        expect(trackEventSpy).toHaveBeenCalledWith(
          expectedAction,
          defaultTrackingOption,
          expectedCategory,
        );
      });

      it('tracks context preset prompts with the correct event label', async () => {
        const question = MOCK_CONTEXT_PRESETS_RESPONSE.data.aiChatContextPresets.questions[0];

        const expectedEventLabel = 'what_are_the_main_points_from_this_mr_discussion';
        const expectedTrackingOption = {
          ...defaultTrackingOption,
          label: expectedEventLabel,
        };

        const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
        findDuoChat().vm.$emit('send-chat-prompt', question);

        await waitForPromises();
        expect(trackEventSpy).toHaveBeenCalledWith(
          expectedAction,
          expectedTrackingOption,
          expectedCategory,
        );
      });

      it.each([GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'does not track if the sent message is "%s"',
        async (msg) => {
          createComponent();
          const { trackEventSpy } = bindInternalEventDocument(wrapper.element);
          findDuoChat().vm.$emit('send-chat-prompt', msg);

          await waitForPromises();
          expect(trackEventSpy).not.toHaveBeenCalled();
        },
      );
    });

    describe('navigateToChat', () => {
      beforeEach(() => {
        threadQueryHandlerMock.mockResolvedValue({
          data: {
            aiMessages: {
              nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
            },
          },
        });
      });

      it('navigates to /chat when selecting a thread from different route', async () => {
        createComponent({ routePath: '/history' });
        await waitForPromises();

        findDuoChat().vm.$emit('thread-selected', {
          id: 'gid://gitlab/Ai::Conversation::Thread/123',
        });
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: CLASSIC_CHAT_SHOW_ROUTE,
          params: { id: '123' },
        });
      });

      it('navigates to /chat when sending a prompt from a new chat', async () => {
        createComponent({ routePath: '/new' });
        await waitForPromises();

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith(
          expect.objectContaining({ name: CLASSIC_CHAT_SHOW_ROUTE }),
        );
      });
    });

    describe('switchMode', () => {
      beforeEach(() => {
        threadQueryHandlerMock.mockResolvedValue({
          data: {
            aiMessages: {
              nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
            },
          },
        });
      });

      it('loads active thread when mode is "chat" and activeThread exists', async () => {
        createComponent({
          propsData: { userId: MOCK_USER_ID, mode: 'chat' },
          routeParams: { id: '123' },
        });
        await waitForPromises();

        expect(threadQueryHandlerMock).toHaveBeenCalledWith(
          expect.objectContaining({ threadId: 'gid://gitlab/Ai::Conversation::Thread/123' }),
        );
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), [
          MOCK_USER_MESSAGE,
          MOCK_TANUKI_MESSAGE,
        ]);
      });

      it('starts new chat when mode is "chat" and no activeThread exists', async () => {
        createComponent({ propsData: { userId: MOCK_USER_ID, mode: 'chat' } });
        await waitForPromises();

        expect(threadQueryHandlerMock).not.toHaveBeenCalled();
        const duoChat = findDuoChat();
        expect(duoChat.props('multiThreadedView')).toBe('chat');
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      });

      it('starts new chat when mode is "new"', async () => {
        createComponent({ propsData: { userId: MOCK_USER_ID, mode: 'new' } });
        await waitForPromises();

        const duoChat = findDuoChat();
        expect(duoChat.props('multiThreadedView')).toBe('chat');
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      });

      it('shows thread list when mode is "history"', async () => {
        conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);
        createComponent({ propsData: { userId: MOCK_USER_ID, mode: 'history' } });
        await waitForPromises();

        const duoChat = findDuoChat();
        expect(duoChat.props('multiThreadedView')).toBe('list');
        expect(wrapper.emitted('change-title')).toBeDefined();
        expect(wrapper.emitted('change-title')[0]).toEqual(['']);
      });

      it('does not auto-select thread when in list view', async () => {
        conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);
        createComponent({ propsData: { userId: MOCK_USER_ID, mode: 'history' } });
        await waitForPromises();

        expect(findDuoChat().props('multiThreadedView')).toBe('list');
        expect(findDuoChat().props('threadList')).toEqual(MOCK_THREADS);
      });

      it('defaults to mode "new" when no mode prop is provided', async () => {
        createComponent({ propsData: { userId: MOCK_USER_ID } });
        await waitForPromises();

        const duoChat = findDuoChat();
        expect(duoChat.props('multiThreadedView')).toBe('chat');
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      });
    });
  });

  describe('@response-received', () => {
    beforeEach(() => {
      performance.mark = jest.fn();
      performance.measure = jest.fn();
      performance.getEntriesByName = jest.fn(() => [{ duration: 123 }]);
      performance.clearMarks = jest.fn();
      performance.clearMeasures = jest.fn();
    });

    describe('when mutation fails', () => {
      const errorText = 'API Error';
      it('throws an error, but still calls addDuoChatMessage', async () => {
        chatMutationHandlerMock.mockRejectedValue(new Error(errorText));
        createComponent();
        await waitForPromises();
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();
        expect(findDuoChat().exists()).toBe(true);
      });
    });
  });
});

describe('Subscription Component', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it('renders AiResponseSubscription component with correct props', async () => {
    createComponent();
    await waitForPromises();

    expect(findSubscriptions().exists()).toBe(true);
    expect(findSubscriptions().props('userId')).toBe(MOCK_USER_ID);
    expect(findSubscriptions().props('clientSubscriptionId')).toBe(UUIDMOCK);
    expect(findSubscriptions().props('cancelledRequestIds')).toHaveLength(0);
  });

  it('calls addDuoChatMessage when @message is fired', () => {
    createComponent();
    const mockMessage = {
      content: 'test message content',
      role: 'user',
    };

    findSubscriptions().vm.$emit('message', mockMessage);
    expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), mockMessage);
  });

  it('sets false to loading state when assistant message is received', () => {
    createComponent();

    wrapper.vm.isWaitingOnPrompt = true;

    const mockMessage = {
      content: 'test message content',
      role: 'assistant',
    };

    findSubscriptions().vm.$emit('message', mockMessage);
    expect(wrapper.vm.isWaitingOnPrompt).toBe(false);
  });

  describe('message streaming', () => {
    beforeEach(() => {
      createComponent();
      performance.mark = jest.fn();
    });

    it('stops adding new messages when more chunks with the same request ID come in after the full message has already been received', () => {
      const requestId = '123';
      const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
      const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, requestId);
      const successResponse = GENERATE_MOCK_TANUKI_RES('', requestId);

      // message chunk streaming in
      findSubscriptions().vm.$emit('message-stream', firstChunk);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), firstChunk);

      // full message being sent
      findSubscriptions().vm.$emit('message', successResponse);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        successResponse,
      );
      // another chunk with the same request ID
      findSubscriptions().vm.$emit('message-stream', secondChunk);
      // addDuoChatMessage should not be called since the full message was already sent
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(2);
    });

    it('continues to invoke addDuoChatMessage when a new message chunk arrives with a distinct request ID, even after a complete message has been received', () => {
      const firstRequestId = '123';
      const secondRequestId = '124';
      const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, firstRequestId);
      const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, firstRequestId);
      const successResponse = GENERATE_MOCK_TANUKI_RES('', secondRequestId);

      // message chunk streaming in
      findSubscriptions().vm.$emit('message-stream', firstChunk);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), firstChunk);

      // full message being sent
      findSubscriptions().vm.$emit('message', successResponse);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        successResponse,
      );
      // another chunk with a new request ID
      findSubscriptions().vm.$emit('message-stream', secondChunk);
      // addDuoChatMessage should be called since the second chunk has a new requestId
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        successResponse,
      );
    });
  });
});

describe('multi-threaded chat functionality', () => {
  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  describe('chat mutation selection and conversation type', () => {
    const mockThreadId = 'gid://gitlab/Ai::Conversation::Thread/123';
    const mockMessagesData = {
      data: {
        aiMessages: {
          nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
        },
      },
    };

    it('uses correct conversation type DUO_CHAT when sending a message and no active thread exists', async () => {
      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

      await nextTick();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: MOCK_USER_MESSAGE.content,
        resourceId: 'gid://gitlab/Issue/1',
        projectId: null,
        conversationType: 'DUO_CHAT',
      });
    });

    it('uses correct conversation type DUO_CHAT when sending a message and active thread exists', async () => {
      threadQueryHandlerMock.mockResolvedValue(mockMessagesData);
      createComponent();

      findDuoChat().vm.$emit('thread-selected', { id: mockThreadId });
      await waitForPromises();

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await nextTick();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: MOCK_USER_MESSAGE.content,
        resourceId: MOCK_RESOURCE_ID,
        projectId: null,
        conversationType: 'DUO_CHAT',
        threadId: mockThreadId,
      });
    });
  });

  describe('rootNamespaceId handling', () => {
    it('uses chatWithNamespaceMutation when rootNamespaceId is provided', async () => {
      createComponent({
        propsData: {
          userId: MOCK_USER_ID,
          resourceId: MOCK_RESOURCE_ID,
          rootNamespaceId: 'namespace-123',
        },
      });

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await nextTick();

      expect(chatWithNamespaceMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: MOCK_USER_MESSAGE.content,
        resourceId: MOCK_RESOURCE_ID,
        projectId: null,
        conversationType: 'DUO_CHAT',
        rootNamespaceId: 'namespace-123',
        threadId: undefined,
      });

      expect(chatMutationHandlerMock).not.toHaveBeenCalled();
    });

    it('uses chatMutation when rootNamespaceId is not provided', async () => {
      createComponent({
        propsData: {
          userId: MOCK_USER_ID,
          resourceId: MOCK_RESOURCE_ID,
        },
      });

      findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
      await nextTick();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: MOCK_USER_MESSAGE.content,
        resourceId: MOCK_RESOURCE_ID,
        projectId: null,
        conversationType: 'DUO_CHAT',
        threadId: undefined,
      });

      expect(chatWithNamespaceMutationHandlerMock).not.toHaveBeenCalled();
    });
  });

  describe('thread handling', () => {
    describe('onThreadSelected', () => {
      const mockThreadId = 'thread-123';
      const mockMessagesData = {
        data: {
          aiMessages: {
            nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
          },
        },
      };

      it('loads messages for selected thread', async () => {
        threadQueryHandlerMock.mockResolvedValue(mockMessagesData);
        createComponent();
        await waitForPromises();

        findDuoChat().vm.$emit('thread-selected', { id: mockThreadId });
        await waitForPromises();

        expect(threadQueryHandlerMock).toHaveBeenCalledWith(
          expect.objectContaining({
            threadId: mockThreadId,
          }),
        );

        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          mockMessagesData.data.aiMessages.nodes,
        );
      });

      it('handles errors when loading thread messages', async () => {
        const error = new Error('Failed to load thread');
        threadQueryHandlerMock.mockRejectedValue(error);
        createComponent();
        await waitForPromises();

        findDuoChat().vm.$emit('thread-selected', { id: mockThreadId });
        await waitForPromises();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: [error.toString()],
          }),
        );
      });
    });

    describe('onNewChat', () => {
      it('resets chat state for new conversation', async () => {
        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        const duoChat = findDuoChat();
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
        expect(duoChat.props('multiThreadedView')).toBe('chat');
        expect(duoChat.props('canceledRequestIds')).toEqual([]);
      });

      describe('when coming from the history route', () => {
        beforeEach(async () => {
          createComponent({
            routeName: CLASSIC_CHAT_HISTORY_ROUTE,
            propsData: { ...MOCK_DEFAULT_PROPS, mode: 'history' },
          });
          mockRouter.push.mockClear();

          findDuoChat().vm.$emit('new-chat');
          await nextTick();
        });

        it('pushes the chat route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith(
            expect.objectContaining({ name: CLASSIC_CHAT_SHOW_ROUTE }),
          );
        });
      });

      describe.each([
        ['the chat route', CLASSIC_CHAT_SHOW_ROUTE],
        ['the new-chat route', CLASSIC_CHAT_NEW_ROUTE],
      ])('when already on %s', (_, routeName) => {
        beforeEach(async () => {
          createComponent({ routeName });
          mockRouter.push.mockClear();

          findDuoChat().vm.$emit('new-chat');
          await nextTick();
        });

        it('does not push', () => {
          expect(mockRouter.push).not.toHaveBeenCalled();
        });
      });

      describe('when a conversation is open', () => {
        beforeEach(async () => {
          // Mount in chat mode so the mount-time switchMode loads the thread
          // instead of firing onNewChat, which would clear the id under test.
          createComponent({
            routeName: CLASSIC_CHAT_SHOW_ROUTE,
            routeParams: { id: '123' },
            propsData: { ...MOCK_DEFAULT_PROPS, mode: 'chat' },
          });
          await waitForPromises();
          mockRouter.push.mockClear();

          findDuoChat().vm.$emit('new-chat');
          await nextTick();
        });

        it('drops the thread id from the route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({
            name: CLASSIC_CHAT_SHOW_ROUTE,
            params: { id: undefined },
          });
        });

        it('stops sending the previous thread id with the next prompt', () => {
          expect(findSubscriptions().props('activeThreadId')).toBe('');
        });
      });

      it('clears duo chat commands when new chat is opened', async () => {
        duoChatGlobalState.commands = [{ question: 'test command' }];
        expect(duoChatGlobalState.commands).toHaveLength(1);

        findDuoChat().vm.$emit('new-chat');
        await nextTick();

        expect(duoChatGlobalState.commands).toHaveLength(0);
      });
    });

    describe('onBackToList', () => {
      describe('when the panel switches to the history mode', () => {
        beforeEach(async () => {
          createComponent();
          mockRouter.push.mockClear();

          await wrapper.setProps({ mode: 'history' });
        });

        it('pushes the history route', () => {
          expect(mockRouter.push).toHaveBeenCalledWith({ name: CLASSIC_CHAT_HISTORY_ROUTE });
        });
      });

      describe('when already on the history route', () => {
        // Landing on the history route must not re-navigate: mounting in
        // history mode is itself the trigger, so nothing is cleared here.
        beforeEach(async () => {
          createComponent({
            routeName: CLASSIC_CHAT_HISTORY_ROUTE,
            propsData: { ...MOCK_DEFAULT_PROPS, mode: 'history' },
          });
          await nextTick();
        });

        it('does not push', () => {
          expect(mockRouter.push).not.toHaveBeenCalled();
        });
      });
    });

    describe('onDeleteThread', () => {
      const mockThreadId = MOCK_THREADS[0].id;
      const remainingThreads = MOCK_THREADS.filter((thread) => thread.id !== mockThreadId);

      beforeEach(async () => {
        conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);
        deleteConversationThreadMutationHandlerMock.mockResolvedValue({
          data: {
            deleteConversationThread: {
              success: true,
              errors: [],
            },
          },
        });
        createComponent();
        await waitForPromises();
        // Reset so we can assert the list query is not fetched again (no refetch).
        conversationThreadsQueryHandlerMock.mockClear();
      });

      it('opens the confirmation modal without deleting when delete is requested', async () => {
        expect(findDeleteThreadModal().props('visible')).toBe(false);

        findDuoChat().vm.$emit('delete-thread', mockThreadId);
        await nextTick();

        // The modal is shown and nothing is deleted yet.
        expect(findDeleteThreadModal().props('visible')).toBe(true);
        expect(deleteConversationThreadMutationHandlerMock).not.toHaveBeenCalled();
        expect(findDuoChat().props('threadList')).toEqual(MOCK_THREADS);
      });

      it('removes the thread from the list without refetching when confirmed', async () => {
        findDuoChat().vm.$emit('delete-thread', mockThreadId);
        await nextTick();

        findDeleteThreadModal().vm.$emit('confirm');
        await waitForPromises();

        // Verify mutation was called with correct variables
        expect(deleteConversationThreadMutationHandlerMock).toHaveBeenCalledWith({
          input: { threadId: mockThreadId },
        });

        // The list query is not refetched.
        expect(conversationThreadsQueryHandlerMock).not.toHaveBeenCalled();

        // The deleted thread is removed from the cached list and the modal closes.
        expect(findDuoChat().props('threadList')).toEqual(remainingThreads);
        expect(findDeleteThreadModal().props('visible')).toBe(false);
      });

      it('shows a loading state on the modal while the mutation is in flight', async () => {
        let resolveMutation;
        deleteConversationThreadMutationHandlerMock.mockReturnValue(
          new Promise((resolve) => {
            resolveMutation = resolve;
          }),
        );

        findDuoChat().vm.$emit('delete-thread', mockThreadId);
        await nextTick();

        findDeleteThreadModal().vm.$emit('confirm');
        await nextTick();

        expect(findDeleteThreadModal().props('loading')).toBe(true);

        resolveMutation({
          data: { deleteConversationThread: { success: true, errors: [] } },
        });
        await waitForPromises();

        expect(findDeleteThreadModal().props('loading')).toBe(false);
        expect(findDeleteThreadModal().props('visible')).toBe(false);
      });

      it('surfaces an error and keeps the list when deletion is unsuccessful', async () => {
        deleteConversationThreadMutationHandlerMock.mockResolvedValue({
          data: {
            deleteConversationThread: {
              success: false,
              errors: ['Boom'],
            },
          },
        });

        findDuoChat().vm.$emit('delete-thread', mockThreadId);
        await nextTick();

        findDeleteThreadModal().vm.$emit('confirm');
        await waitForPromises();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({ errors: ['Error: Boom'] }),
        );
        expect(conversationThreadsQueryHandlerMock).not.toHaveBeenCalled();
        expect(findDuoChat().props('threadList')).toEqual(MOCK_THREADS);
        expect(findDeleteThreadModal().props('loading')).toBe(false);
      });
    });

    describe('thread list loading', () => {
      beforeEach(() => {
        conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);
        threadQueryHandlerMock.mockResolvedValue({
          data: {
            aiMessages: {
              nodes: [MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE],
            },
          },
        });
        createComponent();
      });

      it('does not auto-select when there are no threads', async () => {
        conversationThreadsQueryHandlerMock.mockResolvedValue({
          data: {
            aiConversationThreads: {
              nodes: [],
              __typename: 'AiConversationsThreadConnection',
            },
          },
        });

        createComponent();

        await nextTick();
        await waitForPromises();
        expect(findDuoChat().props('threadList')).toHaveLength(0);
      });

      it('does not auto-select thread when command is from button', async () => {
        conversationThreadsQueryHandlerMock.mockResolvedValue(MOCK_THREADS_RESPONSE);

        duoChatGlobalState.commands = [{ question: 'Button command' }];

        createComponent();

        await waitForPromises();

        expect(wrapper.vm.activeThread).toBe(undefined);
      });
    });
  });
});

describe('aiConversationThreads query', () => {
  it('always runs the query', async () => {
    createComponent();
    await waitForPromises();

    expect(conversationThreadsQueryHandlerMock).toHaveBeenCalledTimes(1);
  });
});

describe('chatTitle functionality', () => {
  it('passes chatTitle prop to DuoChat component', async () => {
    const chatTitle = 'Custom Chat Title';
    createComponent({
      propsData: { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID, chatTitle },
    });
    await nextTick();
    expect(findDuoChat().props('title')).toBe(chatTitle);
  });

  it('passes null as title to DuoChat component when no chatTitle is provided', async () => {
    createComponent();
    await nextTick();
    expect(findDuoChat().props('title')).toBeNull();
  });

  it('updates DuoChat title when chatTitle prop changes', async () => {
    createComponent({
      propsData: {
        chatTitle: 'Initial Title',
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
      },
    });
    expect(wrapper.findComponent(DuoChatView).props('title')).toBe('Initial Title');

    await wrapper.setProps({ chatTitle: 'Updated Title' });
    expect(wrapper.findComponent(DuoChatView).props('title')).toBe('Updated Title');
  });
});

describe('toggle position based on chatMode', () => {
  const findGlToggle = () => wrapper.findComponent(GlToggle);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('shows toggle as checked when in agentic mode', () => {
    duoChatGlobalState.chatMode = 'agentic';
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        isAgenticAvailable: true,
      },
    });

    expect(findGlToggle().props('value')).toBe(true);
  });

  it('shows toggle as unchecked when in classic mode', () => {
    duoChatGlobalState.chatMode = 'classic';
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        isAgenticAvailable: true,
      },
    });

    expect(findGlToggle().props('value')).toBe(false);
  });
});

describe('Agentic Toggle', () => {
  const findGlToggle = () => wrapper.findComponent(GlToggle);

  beforeEach(() => {
    duoChatGlobalState.chatMode = 'classic';
    jest.clearAllMocks();
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        isAgenticAvailable: true,
      },
    });
  });

  it('renders the GlToggle component with "Agentic" label', () => {
    expect(findGlToggle().exists()).toBe(true);
    expect(findGlToggle().text()).toContain('Agentic');
  });

  it('calls setAgenticMode with the toggle value when toggle changes', async () => {
    const toggle = findGlToggle();

    // Toggle directly controls agentic mode - false means agentic mode is disabled
    toggle.vm.$emit('change', false);
    await nextTick();

    expect(setAgenticMode).toHaveBeenCalledWith({
      agenticMode: false,
      saveCookie: true,
    });
  });

  describe('when isAgenticAvailable is false', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render the GlToggle component', () => {
      expect(findGlToggle().exists()).toBe(false);
    });
  });
});

describe('subheader template', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders subheader template with correct component', () => {
    const toggle = findDuoChat();
    expect(toggle.exists()).toBe(true);
  });
});

describe('`focusInput` method', () => {
  it("calls `DuoChatView`'s `focusChatInput` method", async () => {
    const focusChatInput = jest.fn();

    createComponent({
      stubs: {
        DuoChatView: {
          template: '<div />',
          methods: {
            focusChatInput,
          },
        },
      },
    });

    expect(focusChatInput).not.toHaveBeenCalled();

    wrapper.vm.focusInput();

    await nextTick();

    expect(focusChatInput).toHaveBeenCalled();
  });
});

describe('computedTrustedUrls', () => {
  beforeEach(() => {
    window.gon = {};
  });

  afterEach(() => {
    delete window.gon;
  });

  it('includes default trusted URLs (gitlab.com and docs URL)', () => {
    createComponent();
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(trustedUrls).toContain('gitlab.com');
    expect(trustedUrls).toContain(docsUrlHost);
  });

  it('includes instance hostname from gon.gitlab_url when available', () => {
    window.gon.gitlab_url = 'https://my-gitlab.example.com';
    createComponent();
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(trustedUrls).toContain('my-gitlab.example.com');
  });

  it('does not include instance hostname when gon.gitlab_url is not set', () => {
    createComponent();
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(trustedUrls).not.toContain('my-gitlab.example.com');
  });

  it('includes additional URLs passed as props', () => {
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        trustedUrls: ['custom1.example.com', 'custom2.example.com'],
      },
    });
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(trustedUrls).toContain('custom1.example.com');
    expect(trustedUrls).toContain('custom2.example.com');
  });

  it('removes duplicate URLs', () => {
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        trustedUrls: ['gitlab.com', `https://${docsUrlHost}`],
      },
    });
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    const gitlabComCount = trustedUrls.filter((url) => url === 'gitlab.com').length;
    const docsUrlCount = trustedUrls.filter((url) => url === docsUrlHost).length;

    expect(gitlabComCount).toBe(1);
    expect(docsUrlCount).toBe(1);
  });

  it('returns an array of unique hostnames', () => {
    window.gon.gitlab_url = 'https://gitlab.example.com';
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        trustedUrls: ['custom.example.com'],
      },
    });
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(Array.isArray(trustedUrls)).toBe(true);
    expect(new Set(trustedUrls).size).toBe(trustedUrls.length);
  });

  it('handles empty trustedUrls prop gracefully', () => {
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        trustedUrls: [],
      },
    });
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(trustedUrls).toContain('gitlab.com');
    expect(trustedUrls).toContain(docsUrlHost);
  });

  it('handles null trustedUrls prop gracefully', () => {
    createComponent({
      propsData: {
        userId: MOCK_USER_ID,
        resourceId: MOCK_RESOURCE_ID,
        trustedUrls: null,
      },
    });
    const trustedUrls = wrapper.vm.computedTrustedUrls;

    expect(trustedUrls).toContain('gitlab.com');
    expect(trustedUrls).toContain(docsUrlHost);
  });
});
