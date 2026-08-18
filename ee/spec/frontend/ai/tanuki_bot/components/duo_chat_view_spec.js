import Vue, { nextTick } from 'vue';
import { GlCard, GlEmptyState, GlDropdownItem, GlPopover, GlFormTextarea } from '@gitlab/ui';
import {
  DuoChatLoader,
  DuoChatPredefinedPrompts,
  DuoChatContextConversation as DuoChatConversation,
  DuoChatThreads,
  MESSAGE_MODEL_ROLES,
} from '@gitlab/duo-ui';
import DuoChatHeader from 'ee/ai/duo_agentic_chat/components/duo_chat_header.vue';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import DuoChatView, { i18n } from 'ee/ai/tanuki_bot/components/duo_chat_view.vue';
import {
  CHAT_RESET_MESSAGE,
  CHAT_CLEAR_MESSAGE,
  CHAT_NEW_MESSAGE,
  CHAT_INCLUDE_MESSAGE,
} from 'ee/ai/tanuki_bot/constants';
import {
  INCLUDE_SLASH_COMMAND,
  MOCK_RESPONSE_MESSAGE,
  MOCK_USER_PROMPT_MESSAGE,
  SLASH_COMMANDS as slashCommands,
  THREADLIST,
} from '../mock_data';

const invalidSlashCommands = [
  {
    name: '/foo',
  },
  {
    description: '/bar',
  },
  {
    shouldSubmit: true,
  },
];

const mockContextItemMenuHandleKeyUp = jest.fn();
const MockContextItemMenu = {
  name: 'MockContextItemMenu',
  template: '<div>Mock context item menu</div>',
  props: ['open'],
  methods: {
    handleKeyUp: mockContextItemMenuHandleKeyUp,
  },
};

const generatePartialSlashCommands = () => {
  const res = [];
  slashCommands.forEach((command) => {
    res.push(command.name.slice(0, command.name.length - 1));
  });
  return res;
};

describe('DuoChatView', () => {
  let scrollIntoViewMock;
  let wrapper;

  const createComponent = ({
    propsData = {},
    slots = {},
    scopedSlots = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    jest.spyOn(DuoChatLoader.methods, 'computeTransitionWidth').mockImplementation();

    wrapper = mountFn(DuoChatView, {
      propsData,
      slots,
      scopedSlots,
      stubs: {
        DuoChatLoader,
        GlEmptyState,
        DuoChatContextItemMenu: MockContextItemMenu,
        GlPopover,
        DuoChatConversation,
      },
    });
  };

  const findChatComponent = () => wrapper.find('[data-testid="chat-component"]');
  const findChatHistoryComponent = () => wrapper.find('[data-testid="chat-history"]');
  const findChatConversations = () => wrapper.findAllComponents(DuoChatConversation);
  const findCustomLoader = () => wrapper.findComponent(DuoChatLoader);
  const findError = () => wrapper.find('[data-testid="chat-error"]');
  const findFooter = () => wrapper.find('[data-testid="chat-footer"]');
  const findDisclaimer = () => wrapper.find('[data-testid="chat-disclaimer"]');
  const findPromptForm = () => wrapper.findComponent('[data-testid="chat-prompt-form"]');
  const findEmptyState = () => wrapper.find('[data-testid="gl-duo-chat-empty-state"]');
  const findEmptyStateTitle = () => wrapper.find('[data-testid="gl-duo-chat-empty-state-title"]');
  const findPredefined = () => wrapper.findComponent(DuoChatPredefinedPrompts);
  const findChatInput = () => wrapper.findComponent(GlFormTextarea);
  const findSlashCommandsCard = () => wrapper.findComponent(GlCard);
  const findSlashCommands = () => wrapper.findAllComponents(GlDropdownItem);
  const findSelectedSlashCommand = () => wrapper.findComponent('.active-command');
  const findSubmitButton = () => wrapper.findComponent('[data-testid="chat-prompt-submit-button"]');
  const findCancelButton = () => wrapper.find('[data-testid="chat-prompt-cancel-button"]');
  const findContextItemMenu = () => wrapper.findComponent(MockContextItemMenu);
  const findIncludeSlashCommand = () =>
    findSlashCommands().wrappers.find((w) => w.text().includes(CHAT_INCLUDE_MESSAGE));

  const setPromptInput = (val) => findChatInput().vm.$emit('input', val);

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
      ${'does render chat input'}           | ${findChatInput}     | ${true}
    `('$desc', ({ component, shouldRender }) => {
      createComponent();

      expect(component().exists()).toBe(shouldRender);
    });

    describe('when messages exist', () => {
      it('scrolls to the bottom on load', async () => {
        createComponent({ propsData: { messages } });

        await nextTick();

        expect(scrollIntoViewMock).toHaveBeenCalledTimes(1);
      });
    });

    it('does not contain a trustedUrls when not set', () => {
      createComponent({ propsData: { messages } });
      expect(findChatConversations().at(0).props('trustedUrls')).toEqual([]);
    });

    it('sets the trustedUrls appropriately', () => {
      createComponent({ propsData: { messages, trustedUrls: ['gitlab.com'] } });
      expect(findChatConversations().at(0).props('trustedUrls')).toEqual(['gitlab.com']);
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

      it.each([
        'get-context-item-content',
        'insert-code-snippet',
        'copy-code-snippet',
        'copy-message',
        'open-file-path',
        'track-feedback',
      ])('correctly passes payload when "%s" event is emitted from a conversation', (eventName) => {
        createComponent({ propsData: { messages } });

        findChatConversations().at(0).vm.$emit(eventName, 'foo');
        expect(wrapper.emitted()[eventName][0]).toEqual(['foo']);
      });
    });

    describe('emptyStateTitle', () => {
      it.each`
        emptyStateTitle   | expectedTitle
        ${undefined}      | ${'I am GitLab Duo Chat, your personal AI-powered assistant.'}
        ${'custom title'} | ${'custom title'}
      `(
        'displays "$expectedTitle" when emptyStateTitle is "$emptyStateTitle"',
        ({ emptyStateTitle, expectedTitle }) => {
          createComponent({ propsData: { emptyStateTitle } });
          expect(findEmptyStateTitle().text()).toBe(expectedTitle);
        },
      );
    });

    describe('prompt placeholder', () => {
      it.each`
        chatPromptPlaceholder   | commands         | expectedPlaceholder
        ${undefined}            | ${undefined}     | ${"Let's work through this together..."}
        ${''}                   | ${undefined}     | ${"Let's work through this together..."}
        ${'custom placeholder'} | ${undefined}     | ${'custom placeholder'}
        ${undefined}            | ${[]}            | ${"Let's work through this together..."}
        ${''}                   | ${[]}            | ${"Let's work through this together..."}
        ${'custom placeholder'} | ${[]}            | ${'custom placeholder'}
        ${undefined}            | ${slashCommands} | ${'Type /help to learn more'}
        ${''}                   | ${slashCommands} | ${'Type /help to learn more'}
        ${'custom placeholder'} | ${slashCommands} | ${'custom placeholder'}
      `(
        'displays "$expectedPlaceholder" when chatPromptPlaceholder is "$chatPromptPlaceholder", and slashCommands are "$commands"',
        ({ chatPromptPlaceholder, commands, expectedPlaceholder }) => {
          createComponent({ propsData: { chatPromptPlaceholder, slashCommands: commands } });
          expect(findChatInput().attributes('placeholder')).toBe(expectedPlaceholder);
        },
      );
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
      describe('when disclaimer should not be visible', () => {
        it.each`
          testMessages                                              | description
          ${[]}                                                     | ${'no messages'}
          ${[{ role: MESSAGE_MODEL_ROLES.user, content: 'Hello' }]} | ${'only user messages'}
        `('hides disclaimer with $description', ({ testMessages }) => {
          createComponent({ propsData: { messages: testMessages } });
          expect(findDisclaimer().exists()).toBe(true);
          expect(findDisclaimer().classes()).toContain('gl-hidden');
        });
      });

      describe('when disclaimer should be visible', () => {
        it.each`
          testMessages                                                                                                       | description
          ${[{ role: MESSAGE_MODEL_ROLES.assistant, content: 'Hi!' }]}                                                       | ${'only assistant messages'}
          ${[{ role: MESSAGE_MODEL_ROLES.user, content: 'Hello' }, { role: MESSAGE_MODEL_ROLES.assistant, content: 'Hi!' }]} | ${'both user and assistant messages'}
        `('shows disclaimer with correct text with $description', ({ testMessages }) => {
          createComponent({ propsData: { messages: testMessages } });

          expect(findDisclaimer().exists()).toBe(true);
          expect(findDisclaimer().classes()).not.toContain('gl-hidden');
          expect(findDisclaimer().text()).toBe('Responses may be inaccurate. Verify before use.');
        });
      });
    });
  });

  describe('chat', () => {
    const clickSubmit = () =>
      findPromptForm().vm.$emit('submit', {
        preventDefault: jest.fn(),
        stopPropagation: jest.fn(),
      });

    it('does render the prompt input by default', () => {
      createComponent({ propsData: { messages } });
      expect(findChatInput().exists()).toBe(true);
    });

    it('does not render the prompt input if `isChatAvailable` prop is `false`', () => {
      createComponent({ propsData: { messages, isChatAvailable: false } });
      expect(findChatInput().exists()).toBe(false);
    });

    describe('submit/cancel button', () => {
      beforeEach(() => {
        createComponent({ propsData: {}, mountFn: mountExtended });
      });

      it('renders the submitButton initially', () => {
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });

      it('disables the submit button if the prompt is empty', async () => {
        wrapper.vm.prompt = '';
        await nextTick();
        expect(findSubmitButton().props('disabled')).toBe(true);
        wrapper.vm.prompt = 'TEST!';
        await nextTick();
        expect(findSubmitButton().props('disabled')).toBe(false);
      });

      it('renders the cancel button after prompt was submitted', async () => {
        wrapper.vm.prompt = 'TEST!';
        await nextTick();
        clickSubmit();
        await nextTick();
        expect(findSubmitButton().exists()).toBe(false);
        expect(findCancelButton().exists()).toBe(true);
      });

      it('renders submit button after request was canceled', async () => {
        wrapper.vm.prompt = 'TEST!';
        await nextTick();
        clickSubmit();
        await nextTick();

        const cancelButton = findCancelButton();
        await cancelButton.trigger('click');
        await nextTick();

        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });
    });

    describe('submit', () => {
      const ENTER = 'Enter';

      it('trims the prompt', () => {
        const question = ' foo bar ';
        const expectedPrompt = 'foo bar';
        createComponent({
          propsData: { isChatAvailable: true, messages: [] },
        });
        setPromptInput(question);
        clickSubmit();
        expect(wrapper.emitted('send-chat-prompt')).toEqual([[expectedPrompt]]);
      });

      it.each`
        trigger                                                                      | event                                | action          | expectEmitted
        ${() => clickSubmit()}                                                       | ${'Submit button click'}             | ${'submit'}     | ${[[promptStr]]}
        ${() => findChatInput().trigger('keyup', { key: ENTER })}                    | ${`Clicking ${ENTER}`}               | ${'submit'}     | ${[[promptStr]]}
        ${() => findChatInput().trigger('keyup', { key: ENTER, metaKey: true })}     | ${`Clicking ${ENTER} + ⌘`}           | ${'not submit'} | ${undefined}
        ${() => findChatInput().trigger('keyup', { key: ENTER, altKey: true })}      | ${`Clicking ${ENTER} + ⎇`}           | ${'not submit'} | ${undefined}
        ${() => findChatInput().trigger('keyup', { key: ENTER, shiftKey: true })}    | ${`Clicking ${ENTER} + ⬆︎`}           | ${'not submit'} | ${undefined}
        ${() => findChatInput().trigger('keyup', { key: ENTER, ctrlKey: true })}     | ${`Clicking ${ENTER} + CTRL`}        | ${'not submit'} | ${undefined}
        ${() => findChatInput().trigger('keyup', { key: ENTER, isComposing: true })} | ${`Clicking ${ENTER} + isComposing`} | ${'not submit'} | ${undefined}
      `('$event should $action the prompt form', ({ trigger, expectEmitted } = {}) => {
        createComponent({
          propsData: { messages: [], isChatAvailable: true },
        });
        setPromptInput(promptStr);
        trigger();
        expect(wrapper.emitted('send-chat-prompt')).toEqual(expectEmitted);
      });

      it('on composition, discards the first enter after composition has ended', async () => {
        // IMEs allow the user to edit the composition after the composition has ended, which requires another press on
        // enter to confirm the composition
        createComponent({
          propsData: { messages: [], isChatAvailable: true },
        });

        setPromptInput(promptStr);

        await findChatInput().vm.$emit('compositionend');

        await findChatInput().trigger('keyup', { key: ENTER });

        expect(wrapper.emitted('send-chat-prompt')).toBeUndefined();

        await findChatInput().trigger('keyup', { key: ENTER });

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[promptStr]]);
      });

      it.each`
        desc                                              | msgs
        ${''}                                             | ${[]}
        ${'with just a user message'}                     | ${[MOCK_USER_PROMPT_MESSAGE]}
        ${'with a user message, and a complete response'} | ${[MOCK_USER_PROMPT_MESSAGE, MOCK_RESPONSE_MESSAGE]}
      `('prevents submission when loading $desc', async ({ msgs } = {}) => {
        createComponent({
          propsData: { isChatAvailable: true, messages: msgs },
        });

        setPromptInput(promptStr);
        clickSubmit();
        await nextTick();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[promptStr]]);

        setPromptInput(promptStr);
        clickSubmit();
        await nextTick();

        expect(wrapper.emitted('send-chat-prompt')).toHaveLength(1);
      });

      it.each([
        [[{ ...MOCK_RESPONSE_MESSAGE, content: undefined, chunks: [''] }]],
        [
          [
            MOCK_USER_PROMPT_MESSAGE,
            { ...MOCK_RESPONSE_MESSAGE, content: undefined, chunks: [''] },
          ],
        ],
        [[{ ...MOCK_RESPONSE_MESSAGE, chunkId: 1 }]],
      ])('prevents submission when streaming (messages = "%o")', async (msgs = []) => {
        createComponent({
          propsData: { isChatAvailable: true, messages: msgs },
        });

        setPromptInput(promptStr);
        clickSubmit();
        await nextTick();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[promptStr]]);

        setPromptInput(promptStr);
        clickSubmit();
        await nextTick();

        expect(wrapper.emitted('send-chat-prompt')).toHaveLength(1);
      });

      it('resets the prompt after form submission', async () => {
        createComponent();
        await setPromptInput(promptStr);
        expect(findChatInput().props('value')).toBe(promptStr);

        clickSubmit();
        await nextTick();

        expect(findChatInput().props('value')).toBe('');
      });

      it('focuses on prompt after form submission', async () => {
        const focusSpy = jest.fn();
        jest.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function focusMockImpl() {
          focusSpy(this);
        });
        createComponent({ mountFn: mountExtended });
        wrapper.vm.prompt = 'TEST!';
        await nextTick();

        clickSubmit();
        await nextTick();

        const expectedElement =
          findChatInput().element.querySelector('textarea') || findChatInput().element;
        expect(focusSpy).toHaveBeenCalledWith(expectedElement);
      });
    });

    describe('clear', () => {
      it('does not render cancel button on clear', async () => {
        createComponent({
          propsData: { messages, isChatAvailable: true },
          mountFn: mountExtended,
        });
        setPromptInput(CHAT_CLEAR_MESSAGE);
        clickSubmit();

        await nextTick();
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });
    });

    describe('new', () => {
      it('does not render cancel button on new', async () => {
        createComponent({
          propsData: { messages, isChatAvailable: true },
          mountFn: mountExtended,
        });
        setPromptInput(CHAT_NEW_MESSAGE);
        clickSubmit();

        await nextTick();
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });

      it('sets focus to input when new chat is created', async () => {
        const focusSpy = jest.fn();
        jest.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function focusMockImpl() {
          focusSpy(this);
        });

        createComponent({
          propsData: { messages, isChatAvailable: true },
          mountFn: mountExtended,
        });

        wrapper.vm.onNewChat();
        await nextTick();

        const expectedElement =
          findChatInput().element.querySelector('textarea') || findChatInput().element;
        expect(focusSpy).toHaveBeenCalledWith(expectedElement);
      });
    });

    describe('reset', () => {
      it('emits the event with the reset prompt', async () => {
        createComponent({
          propsData: { messages, isChatAvailable: true },
          mountFn: mountExtended,
        });
        wrapper.vm.prompt = CHAT_RESET_MESSAGE;
        await nextTick();
        clickSubmit();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[CHAT_RESET_MESSAGE]]);
        expect(findChatConversations()).toHaveLength(1);
        await nextTick();
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });
    });

    describe('cancel', () => {
      it('emits cancel event on cancel button click', async () => {
        createComponent({ propsData: {}, mountFn: mountExtended });
        wrapper.vm.prompt = 'TEST!';
        await nextTick();
        clickSubmit();
        await nextTick();
        const cancelButton = findCancelButton();
        expect(cancelButton.exists()).toBe(true);
        await cancelButton.trigger('click');
        expect(wrapper.emitted('chat-cancel')).toHaveLength(1);
      });

      it('cancel button toggles correctly when last message contains incomplete stream chunks', async () => {
        const unfinishedStreamMessage = { ...MOCK_RESPONSE_MESSAGE, chunkId: 1 };
        const propsBase = () => ({
          messages: [unfinishedStreamMessage],
          canceledRequestIds: [MOCK_RESPONSE_MESSAGE.requestId],
          isLoading: false,
        });
        createComponent({ propsData: propsBase(), mountFn: mountExtended });

        // Expect submit button
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);

        // User submits a new prompt, which resets button state
        wrapper.vm.prompt = 'TEST!';
        await nextTick();
        clickSubmit();
        await nextTick();

        // Expect cancel button
        expect(findSubmitButton().exists()).toBe(false);
        expect(findCancelButton().exists()).toBe(true);

        // User message is added
        wrapper.setProps({
          ...propsBase(),
          messages: [unfinishedStreamMessage, MOCK_USER_PROMPT_MESSAGE],
        });
        await nextTick();

        // This should not reset the button state
        // Expect cancel button
        expect(findSubmitButton().exists()).toBe(false);
        expect(findCancelButton().exists()).toBe(true);

        // Set isLoading to true
        wrapper.setProps({
          ...propsBase(),
          messages: [unfinishedStreamMessage, MOCK_USER_PROMPT_MESSAGE],
          isLoading: true,
        });
        await nextTick();

        // Expect cancel button
        expect(findSubmitButton().exists()).toBe(false);
        expect(findCancelButton().exists()).toBe(true);
      });
    });

    describe('when chat has a content-items-menu component in slot', () => {
      beforeEach(() => {
        createComponent({
          mountFn: mountExtended,
          propsData: {
            slashCommands: [...slashCommands, INCLUDE_SLASH_COMMAND],
            predefinedPrompts: ['Foo bar baz?'],
          },
          scopedSlots: {
            'context-items-menu': ({ isOpen, setRef, onClose, focusPrompt }) => {
              if (process.env.VUE_VERSION === '3') {
                return Vue.h(MockContextItemMenu, {
                  open: isOpen,
                  onClose,
                  onFocusPrompt: focusPrompt,
                  ref: setRef,
                });
              }
              // Vue 2 vNode creation
              return Vue.h(MockContextItemMenu, {
                props: {
                  open: isOpen,
                },
                on: {
                  close: onClose,
                  'focus-prompt': focusPrompt,
                },
                ref: setRef,
              });
            },
          },
        });
      });

      it('does not open context menu by default', () => {
        expect(findContextItemMenu().exists()).toBe(true);
        expect(findContextItemMenu().props('open')).toBe(false);
      });

      it('shows "/include" slash command in list', async () => {
        // Manually set the context menu ref to simulate the scoped slot setup
        wrapper.vm.setContextItemsMenuRef({ handleKeyUp: mockContextItemMenuHandleKeyUp });
        await setPromptInput('/');
        await nextTick();

        expect(findIncludeSlashCommand().exists()).toBe(true);
      });

      it.each(['/include', '/incl'])(
        'opens context menu when running "%s" command',
        async (command) => {
          // Manually set the context menu ref to simulate the scoped slot setup
          wrapper.vm.setContextItemsMenuRef({ handleKeyUp: mockContextItemMenuHandleKeyUp });
          await setPromptInput(command);
          await nextTick();

          findChatInput().find('textarea').trigger('keyup', { key: 'Enter' });
          await nextTick();
          await nextTick();

          expect(findContextItemMenu().props('open')).toBe(true);
        },
      );

      it('opens context menu when manually typing full "/include" command', async () => {
        // Manually set the context menu ref to simulate the scoped slot setup
        wrapper.vm.setContextItemsMenuRef({ handleKeyUp: mockContextItemMenuHandleKeyUp });
        await setPromptInput('/include');
        await nextTick();

        findChatInput().find('textarea').trigger('keyup', { key: '' });
        await nextTick();

        expect(findContextItemMenu().props('open')).toBe(true);
      });

      describe('when the context menu is open', () => {
        beforeEach(async () => {
          // Manually set the context menu ref to simulate the scoped slot setup
          wrapper.vm.setContextItemsMenuRef({ handleKeyUp: mockContextItemMenuHandleKeyUp });
          await setPromptInput('/include');
          await nextTick();

          findChatInput().find('textarea').trigger('keyup', { key: 'Enter' });
          await nextTick();
        });

        it('does not show the slash command menu', () => {
          expect(findSlashCommandsCard().exists()).toBe(false);
        });

        it('closes context menu when calling onClose', async () => {
          findContextItemMenu().vm.$emit('close');
          await nextTick();

          expect(findContextItemMenu().props('open')).toBe(false);
        });

        it('closes context menu when clicking a predefined prompt', async () => {
          findPredefined().vm.$emit('click', 'Some predefined prompt');
          await nextTick();

          expect(findContextItemMenu().props('open')).toBe(false);
        });

        it.each(['/', '', 'how does bread?'])(
          'closes context menu when prompt is modified to "%s"',
          async (newPrompt) => {
            await setPromptInput(newPrompt);
            findChatInput().find('textarea').trigger('keyup', { key: 'ArrowRight' });
            await nextTick();

            expect(findContextItemMenu().props('open')).toBe(false);
          },
        );

        it('focuses on prompt when calling focusPrompt', async () => {
          const focusSpy = jest.fn();
          jest.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function focusMockImpl() {
            focusSpy(this);
          });

          findContextItemMenu().vm.$emit('focus-prompt');
          await nextTick();

          const expectedElement =
            findChatInput().element.querySelector('textarea') || findChatInput().element;
          expect(focusSpy).toHaveBeenCalledWith(expectedElement);
        });

        it('passes keyboard events to component ref when the menu is open', async () => {
          findChatInput().find('textarea').trigger('keyup', { key: 'ArrowDown' });
          await nextTick();
          expect(mockContextItemMenuHandleKeyUp).toHaveBeenCalledWith(
            expect.objectContaining({ key: 'ArrowDown' }),
          );

          findChatInput().find('textarea').trigger('keyup', { key: 'ArrowUp' });
          expect(mockContextItemMenuHandleKeyUp).toHaveBeenCalledWith(
            expect.objectContaining({ key: 'ArrowUp' }),
          );

          findChatInput().find('textarea').trigger('keyup', { key: 'Z' });
          expect(mockContextItemMenuHandleKeyUp).toHaveBeenCalledWith(
            expect.objectContaining({ key: 'Z' }),
          );
        });
      });
    });

    describe('undo/redo methods', () => {
      beforeEach(() => {
        document.execCommand = jest.fn();
        createComponent({ propsData: { messages }, mountFn: mountExtended });
      });

      it.each`
        desc                       | eventOptions                                   | expectedCommand
        ${'Ctrl+Z for undo'}       | ${{ key: 'z', ctrlKey: true }}                 | ${'undo'}
        ${'Cmd+Z for undo'}        | ${{ key: 'z', metaKey: true }}                 | ${'undo'}
        ${'Ctrl+Shift+Z for redo'} | ${{ key: 'z', ctrlKey: true, shiftKey: true }} | ${'redo'}
        ${'Cmd+Shift+Z for redo'}  | ${{ key: 'z', metaKey: true, shiftKey: true }} | ${'redo'}
        ${'Ctrl+Y for redo'}       | ${{ key: 'y', ctrlKey: true }}                 | ${'redo'}
        ${'Cmd+Y for redo'}        | ${{ key: 'y', metaKey: true }}                 | ${'redo'}
      `('handles $desc', async ({ eventOptions, expectedCommand }) => {
        await findChatInput().find('textarea').trigger('keydown', eventOptions);

        expect(document.execCommand).toHaveBeenCalledWith(expectedCommand);
      });
    });

    describe('verify all keys are working correctly', () => {
      beforeEach(() => {
        createComponent({ propsData: {}, mountFn: mountExtended });
      });

      it.each`
        desc                 | eventOptions                                 | expectedCommand
        ${'a'}               | ${{ key: 'a' }}                              | ${'a'}
        ${'b'}               | ${{ key: 'b' }}                              | ${'b'}
        ${'c'}               | ${{ key: 'c' }}                              | ${'c'}
        ${'d'}               | ${{ key: 'd' }}                              | ${'d'}
        ${'e'}               | ${{ key: 'e' }}                              | ${'e'}
        ${'f'}               | ${{ key: 'f' }}                              | ${'f'}
        ${'g'}               | ${{ key: 'g' }}                              | ${'g'}
        ${'h'}               | ${{ key: 'h' }}                              | ${'h'}
        ${'i'}               | ${{ key: 'i' }}                              | ${'i'}
        ${'j'}               | ${{ key: 'j' }}                              | ${'j'}
        ${'k'}               | ${{ key: 'k' }}                              | ${'k'}
        ${'l'}               | ${{ key: 'l' }}                              | ${'l'}
        ${'m'}               | ${{ key: 'm' }}                              | ${'m'}
        ${'n'}               | ${{ key: 'n' }}                              | ${'n'}
        ${'o'}               | ${{ key: 'o' }}                              | ${'o'}
        ${'p'}               | ${{ key: 'p' }}                              | ${'p'}
        ${'q'}               | ${{ key: 'q' }}                              | ${'q'}
        ${'r'}               | ${{ key: 'r' }}                              | ${'r'}
        ${'s'}               | ${{ key: 's' }}                              | ${'s'}
        ${'t'}               | ${{ key: 't' }}                              | ${'t'}
        ${'u'}               | ${{ key: 'u' }}                              | ${'u'}
        ${'v'}               | ${{ key: 'v' }}                              | ${'v'}
        ${'w'}               | ${{ key: 'w' }}                              | ${'w'}
        ${'x'}               | ${{ key: 'x' }}                              | ${'x'}
        ${'y'}               | ${{ key: 'y' }}                              | ${'y'}
        ${'z'}               | ${{ key: 'z' }}                              | ${'z'}
        ${'A'}               | ${{ key: 'A', shiftKey: true }}              | ${'A'}
        ${'B'}               | ${{ key: 'B', shiftKey: true }}              | ${'B'}
        ${'C'}               | ${{ key: 'C', shiftKey: true }}              | ${'C'}
        ${'D'}               | ${{ key: 'D', shiftKey: true }}              | ${'D'}
        ${'E'}               | ${{ key: 'E', shiftKey: true }}              | ${'E'}
        ${'F'}               | ${{ key: 'F', shiftKey: true }}              | ${'F'}
        ${'G'}               | ${{ key: 'G', shiftKey: true }}              | ${'G'}
        ${'H'}               | ${{ key: 'H', shiftKey: true }}              | ${'H'}
        ${'I'}               | ${{ key: 'I', shiftKey: true }}              | ${'I'}
        ${'J'}               | ${{ key: 'J', shiftKey: true }}              | ${'J'}
        ${'K'}               | ${{ key: 'K', shiftKey: true }}              | ${'K'}
        ${'L'}               | ${{ key: 'L', shiftKey: true }}              | ${'L'}
        ${'M'}               | ${{ key: 'M', shiftKey: true }}              | ${'M'}
        ${'N'}               | ${{ key: 'N', shiftKey: true }}              | ${'N'}
        ${'O'}               | ${{ key: 'O', shiftKey: true }}              | ${'O'}
        ${'P'}               | ${{ key: 'P', shiftKey: true }}              | ${'P'}
        ${'Q'}               | ${{ key: 'Q', shiftKey: true }}              | ${'Q'}
        ${'R'}               | ${{ key: 'R', shiftKey: true }}              | ${'R'}
        ${'S'}               | ${{ key: 'S', shiftKey: true }}              | ${'S'}
        ${'T'}               | ${{ key: 'T', shiftKey: true }}              | ${'T'}
        ${'U'}               | ${{ key: 'U', shiftKey: true }}              | ${'U'}
        ${'V'}               | ${{ key: 'V', shiftKey: true }}              | ${'V'}
        ${'W'}               | ${{ key: 'W', shiftKey: true }}              | ${'W'}
        ${'X'}               | ${{ key: 'X', shiftKey: true }}              | ${'X'}
        ${'Y'}               | ${{ key: 'Y', shiftKey: true }}              | ${'Y'}
        ${'Z'}               | ${{ key: 'Z', shiftKey: true }}              | ${'Z'}
        ${'period'}          | ${{ key: '.' }}                              | ${'.'}
        ${'comma'}           | ${{ key: ',' }}                              | ${','}
        ${'semicolon'}       | ${{ key: ';' }}                              | ${';'}
        ${'apostrophe'}      | ${{ key: "'" }}                              | ${"'"}
        ${'slash'}           | ${{ key: '/' }}                              | ${'/'}
        ${'backslash'}       | ${{ key: '\\' }}                             | ${'\\'}
        ${'bracket left'}    | ${{ key: '[' }}                              | ${'['}
        ${'bracket right'}   | ${{ key: ']' }}                              | ${']'}
        ${'minus'}           | ${{ key: '-' }}                              | ${'-'}
        ${'equals'}          | ${{ key: '=' }}                              | ${'='}
        ${'question mark'}   | ${{ key: '?', shiftKey: true }}              | ${'?'}
        ${'exclamation'}     | ${{ key: '!', shiftKey: true }}              | ${'!'}
        ${'colon'}           | ${{ key: ':', shiftKey: true }}              | ${':'}
        ${'quotes'}          | ${{ key: '"', shiftKey: true }}              | ${'"'}
        ${'less than'}       | ${{ key: '<', shiftKey: true }}              | ${'<'}
        ${'greater than'}    | ${{ key: '>', shiftKey: true }}              | ${'>'}
        ${'underscore'}      | ${{ key: '_', shiftKey: true }}              | ${'_'}
        ${'plus'}            | ${{ key: '+', shiftKey: true }}              | ${'+'}
        ${'paren left'}      | ${{ key: '(', shiftKey: true }}              | ${'('}
        ${'paren right'}     | ${{ key: ')', shiftKey: true }}              | ${')'}
        ${'curly left'}      | ${{ key: '{', shiftKey: true }}              | ${'{'}
        ${'curly right'}     | ${{ key: '}', shiftKey: true }}              | ${'}'}
        ${'pipe'}            | ${{ key: '|', shiftKey: true }}              | ${'|'}
        ${'at symbol'}       | ${{ key: '@', shiftKey: true }}              | ${'@'}
        ${'hash'}            | ${{ key: '#', shiftKey: true }}              | ${'#'}
        ${'dollar'}          | ${{ key: '$', shiftKey: true }}              | ${'$'}
        ${'percent'}         | ${{ key: '%', shiftKey: true }}              | ${'%'}
        ${'caret'}           | ${{ key: '^', shiftKey: true }}              | ${'^'}
        ${'ampersand'}       | ${{ key: '&', shiftKey: true }}              | ${'&'}
        ${'asterisk'}        | ${{ key: '*', shiftKey: true }}              | ${'*'}
        ${'Tab'}             | ${{ key: 'Tab' }}                            | ${'Tab'}
        ${'Escape'}          | ${{ key: 'Escape' }}                         | ${'Escape'}
        ${'Backspace'}       | ${{ key: 'Backspace' }}                      | ${'Backspace'}
        ${'Delete'}          | ${{ key: 'Delete' }}                         | ${'Delete'}
        ${'ArrowUp'}         | ${{ key: 'ArrowUp' }}                        | ${'ArrowUp'}
        ${'ArrowDown'}       | ${{ key: 'ArrowDown' }}                      | ${'ArrowDown'}
        ${'ArrowLeft'}       | ${{ key: 'ArrowLeft' }}                      | ${'ArrowLeft'}
        ${'ArrowRight'}      | ${{ key: 'ArrowRight' }}                     | ${'ArrowRight'}
        ${'Home'}            | ${{ key: 'Home' }}                           | ${'Home'}
        ${'End'}             | ${{ key: 'End' }}                            | ${'End'}
        ${'PageUp'}          | ${{ key: 'PageUp' }}                         | ${'PageUp'}
        ${'PageDown'}        | ${{ key: 'PageDown' }}                       | ${'PageDown'}
        ${'Ctrl+a (Win)'}    | ${{ key: 'a', ctrlKey: true }}               | ${'selectAll'}
        ${'Cmd+a (Mac)'}     | ${{ key: 'a', metaKey: true }}               | ${'selectAll'}
        ${'Ctrl+c (Win)'}    | ${{ key: 'c', ctrlKey: true }}               | ${'copy'}
        ${'Cmd+c (Mac)'}     | ${{ key: 'c', metaKey: true }}               | ${'copy'}
        ${'Ctrl+x (Win)'}    | ${{ key: 'x', ctrlKey: true }}               | ${'cut'}
        ${'Cmd+x (Mac)'}     | ${{ key: 'x', metaKey: true }}               | ${'cut'}
        ${'Ctrl+v (Win)'}    | ${{ key: 'v', ctrlKey: true }}               | ${'paste'}
        ${'Cmd+v (Mac)'}     | ${{ key: 'v', metaKey: true }}               | ${'paste'}
        ${'Ctrl+s (Win)'}    | ${{ key: 's', ctrlKey: true }}               | ${'save'}
        ${'Cmd+s (Mac)'}     | ${{ key: 's', metaKey: true }}               | ${'save'}
        ${'Ctrl+f (Win)'}    | ${{ key: 'f', ctrlKey: true }}               | ${'find'}
        ${'Cmd+f (Mac)'}     | ${{ key: 'f', metaKey: true }}               | ${'find'}
        ${'Ctrl+h (Win)'}    | ${{ key: 'h', ctrlKey: true }}               | ${'replace'}
        ${'Cmd+Alt+f (Mac)'} | ${{ key: 'f', metaKey: true, altKey: true }} | ${'replace'}
        ${'Ctrl+g (Win)'}    | ${{ key: 'g', ctrlKey: true }}               | ${'findNext'}
        ${'Cmd+g (Mac)'}     | ${{ key: 'g', metaKey: true }}               | ${'findNext'}
        ${'Ctrl+b (Win)'}    | ${{ key: 'b', ctrlKey: true }}               | ${'bold'}
        ${'Cmd+b (Mac)'}     | ${{ key: 'b', metaKey: true }}               | ${'bold'}
        ${'Ctrl+i (Win)'}    | ${{ key: 'i', ctrlKey: true }}               | ${'italic'}
        ${'Cmd+i (Mac)'}     | ${{ key: 'i', metaKey: true }}               | ${'italic'}
        ${'Ctrl+u (Win)'}    | ${{ key: 'u', ctrlKey: true }}               | ${'underline'}
        ${'Cmd+u (Mac)'}     | ${{ key: 'u', metaKey: true }}               | ${'underline'}
        ${'Ctrl+k (Win)'}    | ${{ key: 'k', ctrlKey: true }}               | ${'link'}
        ${'Cmd+k (Mac)'}     | ${{ key: 'k', metaKey: true }}               | ${'link'}
        ${'Ctrl+o (Win)'}    | ${{ key: 'o', ctrlKey: true }}               | ${'open'}
        ${'Cmd+o (Mac)'}     | ${{ key: 'o', metaKey: true }}               | ${'open'}
        ${'Ctrl+n (Win)'}    | ${{ key: 'n', ctrlKey: true }}               | ${'new'}
        ${'Cmd+n (Mac)'}     | ${{ key: 'n', metaKey: true }}               | ${'new'}
        ${'Ctrl+p (Win)'}    | ${{ key: 'p', ctrlKey: true }}               | ${'print'}
        ${'Cmd+p (Mac)'}     | ${{ key: 'p', metaKey: true }}               | ${'print'}
        ${'Ctrl+w (Win)'}    | ${{ key: 'w', ctrlKey: true }}               | ${'close'}
        ${'Cmd+w (Mac)'}     | ${{ key: 'w', metaKey: true }}               | ${'close'}
        ${'Ctrl+q (Win)'}    | ${{ key: 'q', ctrlKey: true }}               | ${'quit'}
        ${'Cmd+q (Mac)'}     | ${{ key: 'q', metaKey: true }}               | ${'quit'}
        ${'Ctrl+r (Win)'}    | ${{ key: 'r', ctrlKey: true }}               | ${'refresh'}
        ${'Cmd+r (Mac)'}     | ${{ key: 'r', metaKey: true }}               | ${'refresh'}
        ${'F5'}              | ${{ key: 'F5' }}                             | ${'refresh'}
        ${'Ctrl+d (Win)'}    | ${{ key: 'd', ctrlKey: true }}               | ${'duplicate'}
        ${'Cmd+d (Mac)'}     | ${{ key: 'd', metaKey: true }}               | ${'duplicate'}
        ${'Ctrl+/ (Win)'}    | ${{ key: '/', ctrlKey: true }}               | ${'comment'}
        ${'Cmd+/ (Mac)'}     | ${{ key: '/', metaKey: true }}               | ${'comment'}
        ${'Ctrl+Enter'}      | ${{ key: 'Enter', ctrlKey: true }}           | ${'submit'}
        ${'Cmd+Enter'}       | ${{ key: 'Enter', metaKey: true }}           | ${'submit'}
        ${'Shift+Enter'}     | ${{ key: 'Enter', shiftKey: true }}          | ${'lineBreak'}
        ${'Shift+Tab'}       | ${{ key: 'Tab', shiftKey: true }}            | ${'outdent'}
        ${'Alt+ArrowUp'}     | ${{ key: 'ArrowUp', altKey: true }}          | ${'moveUp'}
        ${'Alt+ArrowDown'}   | ${{ key: 'ArrowDown', altKey: true }}        | ${'moveDown'}
      `('should handle $desc key', async ({ eventOptions, expectedCommand }) => {
        const preventDefaultSpy = jest.fn();
        const stopPropagationSpy = jest.fn();

        await findChatInput().trigger('keydown', {
          ...eventOptions,
          preventDefault: preventDefaultSpy,
          stopPropagation: stopPropagationSpy,
        });

        expect(preventDefaultSpy).not.toHaveBeenCalled();
        expect(document.execCommand).not.toHaveBeenCalledWith(expectedCommand);

        setPromptInput(expectedCommand);

        findPromptForm().vm.$emit('submit', {
          preventDefault: jest.fn(),
          stopPropagation: jest.fn(),
        });

        await nextTick();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[expectedCommand]]);
      });
    });

    describe('refs used by external consumers', () => {
      // VSCode uses the prompt ref to manually trigger focus in the prompt input when running some VSCode commands
      // https://gitlab.com/gitlab-org/gitlab-vscode-extension/blob/main/webviews/vue2/gitlab_duo_chat/src/App.vue#L112
      describe('prompt ref', () => {
        it('adds prompt ref which external consumer uses', async () => {
          createComponent({ propsData: { messages }, mountFn: mountExtended });
          await nextTick();

          expect(wrapper.vm.$refs.prompt).toBeDefined();
          expect(wrapper.vm.$refs.prompt.$el.focus).toEqual(expect.any(Function));
        });
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

      it('listens to the click event and sends the predefined prompt', async () => {
        findPredefined().vm.$emit('click', prompts[0]);

        await nextTick();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[prompts[0]]]);
      });
    });
  });

  describe('slash commands', () => {
    const slashCommandsNames = slashCommands.map((command) => command.name);
    const slashCommandsOnly = (commands = []) =>
      slashCommandsNames.filter((name) => commands.includes(name));

    describe('rendering', () => {
      describe('without slash commands', () => {
        it('does not render slash commands by default', () => {
          createComponent();
          expect(findSlashCommandsCard().exists()).toBe(false);
        });

        describe('when prompt is "/"', () => {
          beforeEach(async () => {
            createComponent();
            setPromptInput('/');
            await nextTick();
          });

          it('does not render slash', () => {
            expect(findSlashCommandsCard().exists()).toBe(false);
          });

          it('does not emit chat-slash', () => {
            expect(wrapper.emitted('chat-slash')).toBeUndefined();
          });
        });
      });

      describe('with slash commands', () => {
        it('does not render slash commands by default', async () => {
          createComponent({
            propsData: {
              slashCommands,
            },
          });

          await nextTick();
          expect(findSlashCommandsCard().exists()).toBe(false);
        });

        it('prevents passing down invalid slash commands', () => {
          expect(() => {
            wrapper = shallowMountExtended(DuoChatView, {
              propsData: {
                slashCommands: [...slashCommands, ...invalidSlashCommands],
              },
            });
          }).toHaveLength(0);
        });

        it('does not render the "/include" command when there is no context-menu component rendered in the named slot', async () => {
          createComponent({
            mountFn: mountExtended,
            propsData: {
              slashCommands: [...slashCommands, INCLUDE_SLASH_COMMAND],
            },
            scopedSlots: {},
          });
          setPromptInput('/');

          await nextTick();

          expect(findIncludeSlashCommand()).toBeUndefined();
        });

        describe('when the prompt includes the "/" character or no characters', () => {
          beforeEach(() => {
            createComponent({
              propsData: {
                slashCommands,
              },
            });
          });

          describe.each(['', '//', '\\', 'foo', '/foo'])('when prompt is "%s"', (prompt) => {
            beforeEach(async () => {
              setPromptInput(prompt);
              await nextTick();
            });

            it('does not emit a chat-slash event', () => {
              expect(wrapper.emitted('chat-slash')).toBeUndefined();
            });

            it('does not render the slash commands', () => {
              expect(findSlashCommandsCard().exists()).toBe(false);
            });
          });
        });

        describe('when prompt presents a partial match to an existing slash command', () => {
          it.each(generatePartialSlashCommands())(
            'renders the slash commands when prompt is "%s" and is a partial match',
            async (prompt) => {
              createComponent({
                propsData: {
                  slashCommands,
                },
              });
              setPromptInput(prompt);

              await nextTick();
              expect(findSlashCommandsCard().exists()).toBe(true);
            },
          );
        });

        describe('when the prompt matches a complete slash command', () => {
          it.each(slashCommands.map((command) => command.name))(
            'does not render the slash commands when prompt is "%s"',
            async (prompt) => {
              createComponent({
                propsData: {
                  slashCommands,
                },
              });
              setPromptInput(prompt);

              await nextTick();
              expect(findSlashCommandsCard().exists()).toBe(false);
            },
          );
        });
      });

      describe('with slash commands and prompt "/"', () => {
        beforeEach(async () => {
          createComponent({
            propsData: {
              slashCommands,
            },
          });
          setPromptInput('/');
          await nextTick();
        });

        it('renders all slash commands', () => {
          expect(findSlashCommandsCard().exists()).toBe(true);
          expect(findSlashCommands()).toHaveLength(slashCommands.length);

          slashCommands.forEach((command, index) => {
            expect(findSlashCommands().at(index).text()).toContain(command.name);
            expect(findSlashCommands().at(index).text()).toContain(command.description);
          });
        });

        it('emits slash event', () => {
          expect(wrapper.emitted('chat-slash')).toHaveLength(1);
        });
      });
    });

    describe('interaction', () => {
      describe('filtering when user types in partial slash command', () => {
        it.each`
          prompt       | expectedCommands
          ${'/'}       | ${slashCommandsNames}
          ${'/t'}      | ${slashCommandsOnly(['/tests'])}
          ${'/tes'}    | ${slashCommandsOnly(['/tests'])}
          ${'/test'}   | ${slashCommandsOnly(['/tests'])}
          ${'/e'}      | ${slashCommandsOnly(['/explain'])}
          ${'/explai'} | ${slashCommandsOnly(['/explain'])}
          ${'/r'}      | ${slashCommandsOnly(['/reset', '/refactor'])}
          ${'/re'}     | ${slashCommandsOnly(['/reset', '/refactor'])}
          ${'/res'}    | ${slashCommandsOnly(['/reset'])}
          ${'/ref'}    | ${slashCommandsOnly(['/refactor'])}
          ${'/foo'}    | ${[]}
        `(
          'shows $expectedCommands when prompt is $prompt',
          async ({ prompt, expectedCommands } = {}) => {
            createComponent({
              propsData: {
                slashCommands,
              },
            });
            setPromptInput(prompt);

            await nextTick();
            expect(findSlashCommands()).toHaveLength(expectedCommands.length);
            expectedCommands.forEach((command) => {
              expect(findSlashCommandsCard().text()).toContain(command);
            });
          },
        );
      });

      describe('keyboard navigation', () => {
        beforeEach(() => {
          createComponent({
            propsData: {
              slashCommands,
              messages,
            },
          });
          setPromptInput('/');
        });

        it('toggles through commands on ArrowDown', async () => {
          for (const command of slashCommandsNames) {
            expect(findSelectedSlashCommand().text()).toContain(command);
            findChatInput().trigger('keyup', { key: 'ArrowDown' });
            // eslint-disable-next-line no-await-in-loop
            await nextTick();
          }
        });

        it('toggles through commands on ArrowUp', async () => {
          const arr = [...slashCommandsNames].reverse();
          arr.unshift(slashCommandsNames[0]); // it still has the top most command selected on the first run
          for (const command of arr) {
            expect(findSelectedSlashCommand().text()).toContain(command);
            findChatInput().trigger('keyup', { key: 'ArrowUp' });
            // eslint-disable-next-line no-await-in-loop
            await nextTick();
          }
        });

        describe('on Enter', () => {
          const navigateToCommand = async (index) => {
            const command = slashCommandsNames[index];
            if (index) {
              for (let i = 0; i < index; i += 1) {
                findChatInput().trigger('keyup', { key: 'ArrowDown' });
              }
            }
            await nextTick();
            return command;
          };

          it('selects correct command and updates input if command should not submit right away', async () => {
            const commandIndex = slashCommands.findIndex((cmd) => !cmd.shouldSubmit);
            const command = await navigateToCommand(commandIndex);

            expect(findSelectedSlashCommand().text()).toContain(command);
            findChatInput().trigger('keyup', { key: 'Enter' });
            await nextTick();
            expect(findChatInput().props('value')).toBe(`${command} `);
            expect(wrapper.emitted('send-chat-prompt')).toBe(undefined);
          });

          it('selects correct command and submits the prompt if command should submit right away', async () => {
            const commandIndex = slashCommands.findIndex((cmd) => cmd.shouldSubmit);
            const command = await navigateToCommand(commandIndex);

            expect(findSelectedSlashCommand().text()).toContain(command);
            findChatInput().trigger('keyup', { key: 'Enter' });
            await nextTick();
            expect(wrapper.emitted('send-chat-prompt')).toEqual([[command]]);
          });
        });
      });

      describe('mouse navigation', () => {
        beforeEach(() => {
          createComponent({
            propsData: {
              slashCommands,
              messages,
            },
          });
          setPromptInput('/');
        });

        it('updates the selected command when hovering over it', async () => {
          expect(findSelectedSlashCommand().text()).toContain(slashCommandsNames[0]);
          findSlashCommands().at(2).trigger('mouseenter');
          await nextTick();
          expect(findSelectedSlashCommand().text()).toContain(slashCommandsNames[2]);
          expect(findSelectedSlashCommand().text()).not.toContain(slashCommandsNames[0]);
        });

        describe('click', () => {
          it('selects correct command and updates input if command should not submit right away', async () => {
            const commandIndex = slashCommands.findIndex((cmd) => !cmd.shouldSubmit);

            findSlashCommands().at(commandIndex).trigger('mouseenter');
            await nextTick();

            expect(findSelectedSlashCommand().text()).toContain(slashCommandsNames[commandIndex]);

            findSelectedSlashCommand().vm.$emit('click');
            await nextTick();

            expect(findChatInput().props('value')).toBe(`${slashCommandsNames[commandIndex]} `);
            expect(wrapper.emitted('send-chat-prompt')).toBe(undefined);
          });

          it('selects correct command and submits the prompt if command should submit right away', async () => {
            const commandIndex = slashCommands.findIndex((cmd) => cmd.shouldSubmit);

            findSlashCommands().at(commandIndex).trigger('mouseenter');
            await nextTick();

            expect(findSelectedSlashCommand().text()).toContain(slashCommandsNames[commandIndex]);

            findSelectedSlashCommand().vm.$emit('click');
            await nextTick();

            expect(wrapper.emitted('send-chat-prompt')).toEqual([
              [slashCommandsNames[commandIndex]],
            ]);
          });
        });
      });
    });
  });

  describe('thread management', () => {
    describe('thread switching', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            isMultithreaded: true,
            threadList: THREADLIST,
            multiThreadedView: 'list',
            activeThreadId: THREADLIST[0].id,
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
            activeThreadId: THREADLIST[0].id,
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
});
