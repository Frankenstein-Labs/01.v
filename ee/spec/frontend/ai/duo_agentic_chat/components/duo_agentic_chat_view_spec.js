import { nextTick } from 'vue';
import { GlEmptyState, GlPopover } from '@gitlab/ui';
import {
  DuoChatLoader,
  DuoChatPredefinedPrompts,
  DuoChatContextConversation as DuoChatConversation,
  DuoChatThreads,
  MESSAGE_MODEL_ROLES,
} from '@gitlab/duo-ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import DuoChatHeader from 'ee/ai/duo_agentic_chat/components/duo_chat_header.vue';
import SessionPillsBar from 'ee/ai/duo_agentic_chat/components/session_pills/session_pills_bar.vue';
import PromptTextarea from 'ee/ai/duo_agentic_chat/components/prompt_textarea.vue';
import AgenticDuoChatView, {
  i18n,
} from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_view.vue';
import { CHAT_RESET_MESSAGE } from 'ee/ai/tanuki_bot/constants';
import {
  MOCK_RESPONSE_MESSAGE,
  MOCK_USER_PROMPT_MESSAGE,
  THREADLIST,
  AGENTIC_THREADLIST,
} from '../../tanuki_bot/mock_data';

describe('AgenticDuoChatView', () => {
  let scrollIntoViewMock;
  let wrapper;
  let mockFocusChatInput;
  let mockSendPredefinedPrompt;

  const createComponent = ({
    propsData = {},
    slots = {},
    scopedSlots = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    jest.spyOn(DuoChatLoader.methods, 'computeTransitionWidth').mockImplementation();

    mockFocusChatInput = jest.fn();
    mockSendPredefinedPrompt = jest.fn();

    wrapper = mountFn(AgenticDuoChatView, {
      propsData,
      slots,
      scopedSlots,
      stubs: {
        DuoChatLoader,
        GlEmptyState,
        GlPopover,
        DuoChatConversation: stubComponent(DuoChatConversation, {
          props: {
            ...DuoChatConversation.props,
            isRetryEnabled: {
              type: Boolean,
              required: false,
              default: false,
            },
          },
        }),
        PromptTextarea: stubComponent(PromptTextarea, {
          methods: {
            focusChatInput: mockFocusChatInput,
            sendPredefinedPrompt: mockSendPredefinedPrompt,
          },
        }),
      },
    });

    return wrapper;
  };

  const findChatComponent = () => wrapper.find('[data-testid="chat-component"]');
  const findChatHistoryComponent = () => wrapper.find('[data-testid="chat-history"]');
  const findChatConversations = () => wrapper.findAllComponents(DuoChatConversation);
  const findCustomLoader = () => wrapper.findComponent(DuoChatLoader);
  const findError = () => wrapper.find('[data-testid="chat-error"]');
  const findFooter = () => wrapper.find('[data-testid="chat-footer"]');
  const findDisclaimer = () => wrapper.find('[data-testid="chat-disclaimer"]');
  const findPromptTextarea = () => wrapper.findComponent(PromptTextarea);
  const findEmptyState = () => wrapper.find('[data-testid="gl-duo-chat-empty-state"]');
  const findEmptyStateTitle = () => wrapper.find('[data-testid="gl-duo-chat-empty-state-title"]');
  const findPredefined = () => wrapper.findComponent(DuoChatPredefinedPrompts);
  const findChatHeader = () => wrapper.findComponent(DuoChatHeader);
  const findSessionPillsBar = () => wrapper.findComponent(SessionPillsBar);
  const findBeforeFooterSlot = () => wrapper.find('[data-testid="chat-before-footer"]');

  beforeEach(() => {
    scrollIntoViewMock = jest.fn();
    window.HTMLElement.prototype.scrollIntoView = scrollIntoViewMock;
  });

  const promptStr = 'foo';
  const messages = [
    {
      role: MESSAGE_MODEL_ROLES.user,
      content: promptStr,
    },
  ];

  describe('rendering', () => {
    it('passes chatState reason to duo-chat-header when messages exist', () => {
      const chatState = { isEnabled: false, reason: 'No credits remain' };
      createComponent({
        propsData: { chatState, messages },
      });

      expect(findChatHeader().props('info')).toBe(chatState.reason);
    });

    it('does not pass chatState reason to duo-chat-header when no messages exist', () => {
      const chatState = { isEnabled: false, reason: 'No credits remain' };
      createComponent({
        propsData: { chatState, messages: [] },
      });

      expect(findChatHeader().props('info')).toBe('');
    });

    describe('before-footer slot', () => {
      it('renders content passed into the before-footer slot', () => {
        createComponent({
          slots: {
            'before-footer': '<div data-testid="chat-before-footer">Banner content</div>',
          },
        });

        expect(findBeforeFooterSlot().exists()).toBe(true);
      });

      it('renders nothing in the before-footer slot by default', () => {
        createComponent();

        expect(findBeforeFooterSlot().exists()).toBe(false);
      });

      it('does not render the before-footer slot when showing the thread list', () => {
        createComponent({
          propsData: { isMultithreaded: true, currentView: 'list' },
          slots: {
            'before-footer': '<div data-testid="chat-before-footer">Banner content</div>',
          },
        });

        expect(findBeforeFooterSlot().exists()).toBe(false);
      });
    });

    it('does not fail if no messages are passed', () => {
      createComponent({
        propsData: { messages: null },
      });

      expect(findChatConversations()).toHaveLength(0);
      expect(findEmptyState().exists()).toBe(true);
    });

    it.each`
      desc                                  | component            | shouldRender
      ${'renders root component'}           | ${findChatComponent} | ${true}
      ${'renders empty state'}              | ${findEmptyState}    | ${true}
      ${'renders predefined prompts'}       | ${findPredefined}    | ${true}
      ${'does not render loading skeleton'} | ${findCustomLoader}  | ${false}
      ${'does not render chat error'}       | ${findError}         | ${false}
    `('$desc', ({ component, shouldRender }) => {
      createComponent();

      expect(component().exists()).toBe(shouldRender);
    });

    it('renders PromptTextarea component', () => {
      createComponent();

      expect(findPromptTextarea().exists()).toBe(true);
    });

    describe('when messages exist', () => {
      it('scrolls to the bottom on load', async () => {
        createComponent({ propsData: { messages } });

        await nextTick();

        expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
      });
    });

    describe('conversations', () => {
      it('renders conversation with correct props', () => {
        const newMessages = [
          {
            role: MESSAGE_MODEL_ROLES.user,
            content: 'How are you?',
          },
          {
            role: MESSAGE_MODEL_ROLES.assistant,
            content: 'Great!',
          },
        ];
        createComponent({ propsData: { messages: newMessages } });
        expect(findChatConversations().at(0).props('messages')).toEqual(newMessages);
        expect(findChatConversations().at(0).props('showDelimiter')).toEqual(false);
      });

      it('renders one conversation when no reset message is present', () => {
        const newMessages = [
          {
            role: MESSAGE_MODEL_ROLES.user,
            content: 'How are you?',
          },
          {
            role: MESSAGE_MODEL_ROLES.assistant,
            content: 'Great!',
          },
        ];
        createComponent({ propsData: { messages: newMessages } });

        expect(findChatConversations()).toHaveLength(1);
        expect(findChatConversations().at(0).props('showDelimiter')).toEqual(false);
      });

      it('does not render conversations when no message is present', () => {
        createComponent({ propsData: { messages: [] } });

        expect(findChatConversations()).toHaveLength(0);
      });

      it('splits it up into multiple conversations when reset message is present', () => {
        const newMessages = [
          {
            role: MESSAGE_MODEL_ROLES.user,
            content: 'Message 1',
          },
          {
            role: MESSAGE_MODEL_ROLES.assistant,
            content: 'Great!',
          },
          {
            role: MESSAGE_MODEL_ROLES.user,
            content: CHAT_RESET_MESSAGE,
          },
        ];
        createComponent({ propsData: { messages: newMessages } });

        expect(findChatConversations()).toHaveLength(2);
        expect(findChatConversations().at(0).props('showDelimiter')).toEqual(false);
        expect(findChatConversations().at(1).props('showDelimiter')).toEqual(true);
      });

      const tierAccessDeniedMessages = [
        {
          role: MESSAGE_MODEL_ROLES.user,
          content: 'Do the thing',
        },
        {
          role: MESSAGE_MODEL_ROLES.assistant,
          message_type: 'agent',
          message_sub_type: 'tier_access_denied',
          content: 'Not available on your tier',
        },
      ];

      it('on SaaS, rewrites tier_access_denied messages to tool role so they fall through to MessageMap', () => {
        createComponent({ propsData: { messages: tierAccessDeniedMessages, isSaas: true } });

        const rendered = findChatConversations().at(0).props('messages');
        expect(rendered[0]).toEqual(tierAccessDeniedMessages[0]);
        expect(rendered[1]).toEqual({
          ...tierAccessDeniedMessages[1],
          role: 'tool',
          message_type: 'tool',
        });
      });

      it('on self-managed, leaves tier_access_denied messages untouched so they render as the original message', () => {
        createComponent({ propsData: { messages: tierAccessDeniedMessages, isSaas: false } });

        const rendered = findChatConversations().at(0).props('messages');
        expect(rendered[1]).toEqual(tierAccessDeniedMessages[1]);
      });

      it('correctly passes payload when "insert-code-snippet" event is emitted from a conversation', () => {
        createComponent({ propsData: { messages } });

        findChatConversations().at(0).vm.$emit('insert-code-snippet', 'foo');
        expect(wrapper.emitted()['insert-code-snippet'][0]).toEqual(['foo']);
      });

      it('correctly passes payload when "copy-code-snippet" event is emitted from a conversation', () => {
        createComponent({ propsData: { messages } });

        findChatConversations().at(0).vm.$emit('copy-code-snippet', 'foo');
        expect(wrapper.emitted()['copy-code-snippet'][0]).toEqual(['foo']);
      });

      it('correctly passes payload when "copy-message" event is emitted from a conversation', () => {
        createComponent({ propsData: { messages } });

        findChatConversations().at(0).vm.$emit('copy-message', 'foo');
        expect(wrapper.emitted()['copy-message'][0]).toEqual(['foo']);
      });

      it('correctly passes payload when "question-answered" event is emitted from a conversation', () => {
        createComponent({ propsData: { messages } });

        findChatConversations()
          .at(0)
          .vm.$emit('question-answered', { optionId: 'option-a', messageId: 'msg-1' });
        expect(wrapper.emitted()['question-answered'][0]).toEqual([
          { optionId: 'option-a', messageId: 'msg-1' },
        ]);
      });

      describe('isRetryEnabled prop', () => {
        it('defaults to false on the conversation', () => {
          createComponent({ propsData: { messages } });
          expect(findChatConversations().at(0).props('isRetryEnabled')).toBe(false);
        });

        it('forwards isRetryEnabled=true to the conversation', () => {
          createComponent({ propsData: { messages, isRetryEnabled: true } });
          expect(findChatConversations().at(0).props('isRetryEnabled')).toBe(true);
        });

        it('re-emits "retry-message" with the payload when emitted from a conversation', () => {
          createComponent({ propsData: { messages, isRetryEnabled: true } });
          const payload = { id: 'assistant-1', requestId: 'req-1' };

          findChatConversations().at(0).vm.$emit('retry-message', payload);

          expect(wrapper.emitted()['retry-message']).toHaveLength(1);
          expect(wrapper.emitted()['retry-message'][0]).toEqual([payload]);
        });
      });

      it('passes trustedUrls prop to conversation', () => {
        const trustedUrls = ['gitlab.com', 'example.com'];
        createComponent({
          propsData: {
            messages,
            trustedUrls,
          },
        });

        expect(findChatConversations().at(0).props('trustedUrls')).toEqual(trustedUrls);
      });
    });

    describe('emptyStateTitle', () => {
      it.each`
        agentName          | emptyStateTitle   | expectedTitle
        ${null}            | ${undefined}      | ${'I am GitLab Duo Agentic Chat, your personal AI-powered assistant.'}
        ${null}            | ${'custom title'} | ${'custom title'}
        ${'awesome agent'} | ${undefined}      | ${'I am GitLab Duo Agentic Chat, your personal AI-powered assistant.'}
      `(
        'displays "$expectedTitle" when emptyStateTitle is "$emptyStateTitle" and agentName is "$agentName"',
        ({ agentName, emptyStateTitle, expectedTitle }) => {
          createComponent({ propsData: { emptyStateTitle, agentName } });
          expect(findEmptyStateTitle().text()).toBe(expectedTitle);
        },
      );
    });

    describe('custom empty state slot', () => {
      describe('when slot is not provided', () => {
        it('renders default empty state', () => {
          createComponent({ propsData: { messages: [] } });
          expect(findEmptyState().exists()).toBe(true);
          expect(findEmptyStateTitle().exists()).toBe(true);
        });
      });

      describe('when slot is provided', () => {
        it('renders custom content', () => {
          createComponent({
            propsData: { messages: [] },
            slots: {
              'custom-empty-state': '<div data-testid="custom-empty">No credits</div>',
            },
          });
          expect(wrapper.find('[data-testid="custom-empty"]').exists()).toBe(true);
          expect(wrapper.find('[data-testid="custom-empty"]').text()).toBe('No credits');
        });
      });
    });

    describe('footer', () => {
      it.each`
        description          | isMultithreaded | multiThreadedView | expectedFooter
        ${'renders'}         | ${true}         | ${'chat'}         | ${true}
        ${'does not render'} | ${true}         | ${'list'}         | ${false}
        ${'renders'}         | ${false}        | ${'chat'}         | ${true}
        ${'renders'}         | ${false}        | ${'list'}         | ${true}
      `(
        '$description footer when isMultithreaded is $isMultithreaded and multiThreadedView is $multiThreadedView',
        ({ isMultithreaded, multiThreadedView, expectedFooter }) => {
          createComponent({
            propsData: {
              threadList: THREADLIST,
              isMultithreaded,
              multiThreadedView,
            },
          });

          expect(findFooter().exists()).toBe(expectedFooter);
        },
      );
    });

    describe('disclaimer', () => {
      it.each`
        testMessages                                                                                                       | shouldBeVisible
        ${[]}                                                                                                              | ${false}
        ${[{ role: MESSAGE_MODEL_ROLES.user, content: 'Hello' }]}                                                          | ${false}
        ${[{ role: MESSAGE_MODEL_ROLES.assistant, content: 'Hi!' }]}                                                       | ${true}
        ${[{ role: MESSAGE_MODEL_ROLES.user, content: 'Hello' }, { role: MESSAGE_MODEL_ROLES.assistant, content: 'Hi!' }]} | ${true}
      `(
        'visibility matches expected state when shouldBeVisible is $shouldBeVisible',
        ({ testMessages, shouldBeVisible }) => {
          createComponent({ propsData: { messages: testMessages } });

          expect(findDisclaimer().exists()).toBe(true);
          if (shouldBeVisible) {
            expect(findDisclaimer().classes()).not.toContain('gl-hidden');
            expect(findDisclaimer().text()).toBe('Responses may be inaccurate. Verify before use.');
          } else {
            expect(findDisclaimer().classes()).toContain('gl-hidden');
          }
        },
      );
    });

    describe('isBinaryFeedbackEnabled prop', () => {
      it('passes isBinaryFeedbackEnabled prop to conversation component', () => {
        createComponent({
          propsData: {
            messages: [{ role: MESSAGE_MODEL_ROLES.assistant, content: 'Hi!' }],
            isBinaryFeedbackEnabled: true,
          },
        });
        expect(findChatConversations().at(0).props('isBinaryFeedbackEnabled')).toBe(true);
      });
    });

    describe('session pills bar', () => {
      const assistantMessages = [{ role: MESSAGE_MODEL_ROLES.assistant, content: 'Hi!' }];

      it('renders the session pills bar', () => {
        createComponent({ propsData: { messages: assistantMessages } });

        expect(findSessionPillsBar().exists()).toBe(true);
        expect(findSessionPillsBar().props('messages')).toBe(assistantMessages);
      });

      const siblingIndex = (el) => Array.from(el.parentNode.children).indexOf(el);

      it('renders the disclaimer below the form', () => {
        createComponent({ propsData: { messages: assistantMessages } });

        expect(siblingIndex(findDisclaimer().element)).toBeGreaterThan(
          siblingIndex(findPromptTextarea().element),
        );
      });
    });
  });

  describe('PromptTextarea integration', () => {
    it('passes correct props to PromptTextarea', () => {
      const chatState = { isEnabled: true, reason: null };
      createComponent({
        propsData: {
          chatState,
          isChatAvailable: false,
          isLoading: true,
          messages: [MOCK_RESPONSE_MESSAGE],
          chatPromptPlaceholder: 'Type here...',
          webSearchEnabled: true,
        },
      });

      const promptTextarea = findPromptTextarea();
      expect(promptTextarea.props('chatState')).toEqual(chatState);
      expect(promptTextarea.props('isChatAvailable')).toBe(false);
      expect(promptTextarea.props('isLoading')).toBe(true);
      expect(promptTextarea.props('lastMessage')).toEqual(MOCK_RESPONSE_MESSAGE);
      expect(promptTextarea.props('chatPromptPlaceholder')).toBe('Type here...');
      expect(promptTextarea.props('webSearchEnabled')).toBe(true);
    });

    it('re-emits send-chat-prompt when PromptTextarea emits it', () => {
      createComponent();

      findPromptTextarea().vm.$emit('send-chat-prompt', 'hello world');

      expect(wrapper.emitted('send-chat-prompt')).toHaveLength(1);
      expect(wrapper.emitted('send-chat-prompt')[0]).toEqual(['hello world']);
    });

    it('re-emits web-search-toggled when PromptTextarea emits it', () => {
      createComponent();

      findPromptTextarea().vm.$emit('web-search-toggled', true);

      expect(wrapper.emitted('web-search-toggled')).toEqual([[true]]);
    });

    it('re-emits chat-cancel when PromptTextarea emits it', () => {
      createComponent();

      findPromptTextarea().vm.$emit('chat-cancel');

      expect(wrapper.emitted('chat-cancel')).toHaveLength(1);
    });
  });

  describe('chat', () => {
    describe('withFeedback prop', () => {
      it('provides withFeedback as true by default', () => {
        createComponent({
          messages,
          isChatAvailable: true,
        });
        expect(wrapper.vm.withFeedback).toBe(true);
      });

      it('provides the value of withFeedback prop when specified', () => {
        createComponent({
          propsData: {
            messages,
            isChatAvailable: true,
            withFeedback: false,
          },
        });
        expect(findChatConversations().at(0).props('withFeedback')).toBe(false);
      });
    });
  });

  describe('interaction', () => {
    it('renders custom loader when isLoading', () => {
      createComponent({ propsData: { isLoading: true } });
      expect(findCustomLoader().exists()).toBe(true);
    });

    it('does not render the empty state when there are messages available', () => {
      createComponent({ propsData: { messages } });
      expect(findEmptyState().exists()).toBe(false);
    });

    describe('scrolling', () => {
      let element;

      const setupScrolledToBottom = () => {
        jest.spyOn(element, 'scrollTop', 'get').mockReturnValue(100);
        jest.spyOn(element, 'offsetHeight', 'get').mockReturnValue(100);
        jest.spyOn(element, 'scrollHeight', 'get').mockReturnValue(200);
      };

      const setupScrolledUp = () => {
        jest.spyOn(element, 'scrollTop', 'get').mockReturnValue(50);
        jest.spyOn(element, 'offsetHeight', 'get').mockReturnValue(100);
        jest.spyOn(element, 'scrollHeight', 'get').mockReturnValue(200);
      };

      beforeEach(() => {
        createComponent({ propsData: { messages, isChatAvailable: true } });
        element = findChatHistoryComponent().element;
      });

      it('scrolls chat to bottom when a new message is received', async () => {
        setupScrolledToBottom();
        scrollIntoViewMock.mockClear();

        findChatHistoryComponent().trigger('scroll');
        await nextTick();

        expect(scrollIntoViewMock).toHaveBeenCalledTimes(0);

        wrapper.setProps({
          messages: [...messages, MOCK_USER_PROMPT_MESSAGE],
        });
        await nextTick(); // allow messages "watch" to run
        await nextTick(); // then scrollToBottom waits for nextTick

        expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
      });

      it('re-pins chat to bottom when the session pills bar changes height', async () => {
        setupScrolledToBottom();
        scrollIntoViewMock.mockClear();

        findChatHistoryComponent().trigger('scroll');
        await nextTick();

        findSessionPillsBar().vm.$emit('height-change');
        await nextTick(); // scrollToBottom waits for nextTick

        expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
      });

      describe('when the user has explicitly scrolled up', () => {
        beforeEach(() => {
          setupScrolledUp();
          scrollIntoViewMock.mockClear();

          findChatHistoryComponent().trigger('scroll');
          return nextTick();
        });

        it('does not scroll chat to bottom when a new assistant message is received', async () => {
          expect(scrollIntoViewMock).toHaveBeenCalledTimes(0);

          wrapper.setProps({
            messages: [...messages, MOCK_RESPONSE_MESSAGE],
          });
          await nextTick(); // allow messages "watch" to run
          await nextTick(); // then scrollToBottom would wait for nextTick

          expect(scrollIntoViewMock).toHaveBeenCalledTimes(0);
        });

        it('does scrolls chat to bottom when a new user message is received', async () => {
          expect(scrollIntoViewMock).toHaveBeenCalledTimes(0);

          wrapper.setProps({
            messages: [...messages, MOCK_USER_PROMPT_MESSAGE],
          });
          await nextTick(); // allow messages "watch" to run
          await nextTick(); // then scrollToBottom would wait for nextTick

          expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
        });

        it('does not re-pin chat to bottom when the session pills bar changes height', async () => {
          findSessionPillsBar().vm.$emit('height-change');
          await nextTick(); // scrollToBottom would wait for nextTick

          expect(scrollIntoViewMock).toHaveBeenCalledTimes(0);
        });
      });
    });

    describe('predefined prompts', () => {
      const prompts = ['what is a fork'];

      beforeEach(() => {
        createComponent({ propsData: { predefinedPrompts: prompts } });
      });

      it('passes on predefined prompts', () => {
        expect(findPredefined().props().prompts).toEqual(prompts);
      });

      it('listens to the click event and calls sendPredefinedPrompt on promptTextarea ref', async () => {
        findPredefined().vm.$emit('click', prompts[0]);

        await nextTick();

        expect(mockSendPredefinedPrompt).toHaveBeenCalledWith(prompts[0]);
      });
    });
  });

  describe('thread management', () => {
    it('allows setting threads following the Duo Agentic Chat signature', () => {
      createComponent({
        propsData: {
          isMultithreaded: true,
          threadList: AGENTIC_THREADLIST,
          multiThreadedView: 'list',
          loadingThreadList: true,
        },
      });
      const threads = wrapper.findComponent(DuoChatThreads);
      expect(threads.props('threads')).toEqual(AGENTIC_THREADLIST);
      expect(threads.props('loading')).toBe(true);
    });

    describe('thread switching', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
          },
        });
      });

      it('emits thread-selected event when selecting a thread', () => {
        const threads = wrapper.findComponent(DuoChatThreads);
        threads.vm.$emit('select-thread', THREADLIST[1]);

        expect(wrapper.emitted('thread-selected')).toHaveLength(1);
        expect(wrapper.emitted('thread-selected')[0]).toEqual([THREADLIST[1]]);
      });

      it('shows thread list when in list view', () => {
        const threadList = wrapper.findComponent(DuoChatThreads);
        expect(threadList.exists()).toBe(true);
        expect(threadList.props('threads')).toEqual(THREADLIST);
      });
    });

    describe('thread deletion', () => {
      it('emits delete-thread event when deleting a thread', () => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
          },
        });
        const threads = wrapper.findComponent(DuoChatThreads);
        const threadIdToDelete = THREADLIST[0].id;

        threads.vm.$emit('delete-thread', threadIdToDelete);

        expect(wrapper.emitted('delete-thread')).toHaveLength(1);
        expect(wrapper.emitted('delete-thread')[0]).toEqual([threadIdToDelete]);
      });

      it('handles deletion of active thread', () => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
          },
        });

        const threads = wrapper.findComponent(DuoChatThreads);
        threads.vm.$emit('delete-thread', THREADLIST[0].id);

        expect(wrapper.emitted('delete-thread')).toHaveLength(1);
        expect(wrapper.emitted('delete-thread')[0]).toEqual([THREADLIST[0].id]);
      });
    });

    describe('thread list navigation', () => {
      it('shows correct header title in list view', () => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
          },
        });
        const header = wrapper.findComponent(DuoChatHeader);
        expect(header.props('title')).toBe(i18n.CHAT_HISTORY_TITLE);
      });

      it('bubbles up new-chat event from DuoChatThreads', () => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
          },
        });
        const threads = wrapper.findComponent(DuoChatThreads);
        threads.vm.$emit('new-chat');

        expect(wrapper.emitted('new-chat')).toHaveLength(1);
        expect(wrapper.emitted('new-chat')[0]).toEqual([]);
      });

      it('shows thread list in list view', () => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
          },
        });

        const threadList = wrapper.findComponent(DuoChatThreads);
        expect(threadList.props('threads')).toEqual(THREADLIST);
      });

      it('hides thread list in chat view', () => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'chat',
          },
        });
        expect(wrapper.vm.shouldShowThreadList).toBe(false);
      });
    });
  });

  describe('transition-group layout classes', () => {
    const findChatMessages = () => wrapper.find('[data-testid="chat-messages"]');

    it('applies centered classes when custom-empty-state slot provided', () => {
      createComponent({
        propsData: { messages: [] },
        slots: { 'custom-empty-state': '<div>No credits</div>' },
      });
      expect(findChatMessages().classes()).toContain('gl-m-auto');
    });

    it('disables transition when custom-empty-state slot provided', () => {
      createComponent({
        propsData: { messages: [] },
        slots: { 'custom-empty-state': '<div>No credits</div>' },
      });
      expect(findChatMessages().attributes('name')).toBe('');
    });

    it('applies bottom-aligned classes when no custom-empty-state slot', () => {
      createComponent({ propsData: { messages: [] } });
      expect(findChatMessages().classes()).toContain('gl-mt-auto');
    });

    it('applies bottom-aligned classes when custom-empty-state slot provided but has messages', () => {
      createComponent({
        propsData: { messages: [{ role: 'user', content: 'test' }] },
        slots: { 'custom-empty-state': '<div>No credits</div>' },
      });
      expect(findChatMessages().classes()).toContain('gl-mt-auto');
    });

    it('enables transition when no custom-empty-state slot', () => {
      createComponent({ propsData: { messages: [] } });
      expect(findChatMessages().attributes('name')).toBe('message');
    });
  });
});
