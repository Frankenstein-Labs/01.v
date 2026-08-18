import { nextTick } from 'vue';
import { GlForm, GlFormTextarea } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import PromptTextarea from 'ee/ai/duo_agentic_chat/components/prompt_textarea.vue';
import PromptInputActions from 'ee/ai/duo_agentic_chat/components/prompt_input_actions.vue';
import {
  CHAT_RESET_MESSAGE,
  CHAT_CLEAR_MESSAGE,
  CHAT_NEW_MESSAGE,
} from 'ee/ai/tanuki_bot/constants';
import { MOCK_RESPONSE_MESSAGE, MOCK_USER_PROMPT_MESSAGE } from '../../tanuki_bot/mock_data';

// Helper function for waiting for async chat submission operations
const waitForChatSubmission = async () => {
  // Wait for all async operations in sendChatPrompt:
  // 1. Initial form submission
  // 2. setPromptAndFocus() await (includes its own nextTick)
  // 3. $nextTick() before setting canSubmit
  // 4. Additional nextTicks for reactive updates to propagate

  await nextTick();
  await nextTick();
  await nextTick();
};

describe('PromptTextarea', () => {
  let wrapper;

  const createComponent = ({
    propsData = {},
    slots = {},
    scopedSlots = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    wrapper = mountFn(PromptTextarea, {
      propsData,
      slots,
      scopedSlots,
    });

    return wrapper;
  };

  const findChatInput = () => wrapper.findComponent(GlFormTextarea);
  const findChatInputNative = () => findChatInput().find('textarea');
  const findChatTextarea = () => wrapper.findComponent(GlFormTextarea);
  const findSubmitButton = () => wrapper.findComponent('[data-testid="chat-prompt-submit-button"]');
  const findCancelButton = () => wrapper.find('[data-testid="chat-prompt-cancel-button"]');
  const findPromptForm = () => wrapper.findComponent(GlForm);
  const findInputActions = () => wrapper.findComponent(PromptInputActions);

  const setPromptInput = (val) => findChatInput().vm.$emit('input', val);

  const clickSubmit = () =>
    findPromptForm().vm.$emit('submit', {
      preventDefault: jest.fn(),
      stopPropagation: jest.fn(),
    });

  const setFocusAndSubmitMessage = async (message) => {
    await findChatInputNative().trigger('focusin');
    findChatInputNative().element.value = message;
    await findChatInputNative().trigger('input');
    clickSubmit();
    await waitForChatSubmission();
  };

  const promptStr = 'foo';

  describe('rendering', () => {
    describe('prompt placeholder', () => {
      it.each`
        chatPromptPlaceholder   | expectedPlaceholder
        ${undefined}            | ${"Let's work through this together..."}
        ${''}                   | ${"Let's work through this together..."}
        ${'custom placeholder'} | ${'custom placeholder'}
      `(
        'displays "$expectedPlaceholder" when chatPromptPlaceholder is "$chatPromptPlaceholder"',
        ({ chatPromptPlaceholder, expectedPlaceholder }) => {
          createComponent({ propsData: { chatPromptPlaceholder } });
          expect(findChatInput().attributes('placeholder')).toBe(expectedPlaceholder);
        },
      );
    });

    describe('prompt length limit', () => {
      beforeEach(() => {
        createComponent({
          mountFn: mountExtended,
          propsData: {},
        });
      });

      it.each`
        prompt               | message                        | submitDisabled
        ${'a'.repeat(16284)} | ${'100 characters remaining.'} | ${false}
        ${'a'.repeat(16383)} | ${'1 character remaining.'}    | ${false}
        ${'a'.repeat(16384)} | ${'0 characters remaining.'}   | ${false}
        ${'a'.repeat(16385)} | ${'1 character over limit.'}   | ${true}
        ${'a'.repeat(16386)} | ${'2 characters over limit.'}  | ${true}
      `(
        'displays correct prompt length warning "$message"',
        async ({ prompt, message, submitDisabled }) => {
          await wrapper.vm.setPromptAndFocus(prompt);

          expect(findChatTextarea().text()).toContain(message);
          expect(findSubmitButton().props('disabled')).toBe(submitDisabled);
        },
      );
    });

    it.each`
      shouldAutoFocusInput | autofocus
      ${undefined}         | ${'true'}
      ${true}              | ${'true'}
      ${false}             | ${undefined}
    `(
      "sets the textarea's `autofocus` prop to $autofocus when `shouldAutoFocusInput` is $shouldAutoFocusInput",
      ({ shouldAutoFocusInput, autofocus }) => {
        createComponent({
          propsData: {
            shouldAutoFocusInput,
          },
        });

        expect(findChatTextarea().attributes('autofocus')).toBe(autofocus);
      },
    );
  });

  describe('chat', () => {
    it('does render the prompt input by default', () => {
      createComponent({});
      expect(findChatInput().exists()).toBe(true);
    });

    it('disables the prompt input if `isChatAvailable` prop is `false`', () => {
      createComponent({ propsData: { isChatAvailable: false }, mountFn: mountExtended });
      expect(findChatInput().exists()).toBe(true);
      expect(findChatInputNative().element.disabled).toBe(true);
    });

    describe('chatState', () => {
      it('disables the textarea when chatState.isEnabled is false', () => {
        createComponent({
          propsData: { chatState: { isEnabled: false, reason: 'No credits' } },
          mountFn: mountExtended,
        });
        expect(findChatInputNative().element.disabled).toBe(true);
      });

      it('disables the submit button when chatState.isEnabled is false', async () => {
        createComponent({
          propsData: { chatState: { isEnabled: false, reason: 'No credits' } },
          mountFn: mountExtended,
        });
        findChatInputNative().element.value = 'TEST!';
        await findChatInputNative().trigger('input');
        expect(findSubmitButton().props('disabled')).toBe(true);
      });

      it('does not disable textarea when chatState.isEnabled is true', async () => {
        createComponent({
          propsData: { chatState: { isEnabled: true, reason: null } },
          mountFn: mountExtended,
        });
        findChatInputNative().element.value = 'TEST!';
        await findChatInputNative().trigger('input');
        await nextTick();
        expect(findChatInputNative().element.disabled).toBe(false);
      });
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
        setPromptInput('');
        expect(findSubmitButton().props('disabled')).toBe(true);

        findChatInputNative().element.value = 'TEST!';
        await findChatInputNative().trigger('input');
        await nextTick();

        expect(findSubmitButton().props('disabled')).toBe(false);
      });

      it('renders the cancel button after prompt was submitted', async () => {
        wrapper.vm.prompt = 'TEST!';
        clickSubmit();
        await waitForChatSubmission();

        expect(findSubmitButton().exists()).toBe(false);
        expect(findCancelButton().exists()).toBe(true);
      });

      it('renders submit button after request was canceled', async () => {
        await wrapper.vm.setPromptAndFocus('TEST!');
        clickSubmit();
        await waitForChatSubmission();

        const cancelButton = findCancelButton();
        await cancelButton.trigger('click');
        await nextTick();

        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });

      describe('Loading', () => {
        it('renders submit button when chat is not loading and cancel otherwise', async () => {
          wrapper = createComponent({
            propsData: {
              isLoading: false,
            },
            mountFn: mountExtended,
          });

          await nextTick();

          expect(findSubmitButton().exists()).toBe(true);
          expect(findCancelButton().exists()).toBe(false);

          findChatInputNative().element.value = 'TEST!';
          await findChatInputNative().trigger('input');

          clickSubmit();

          await nextTick();

          await waitForChatSubmission();

          expect(findCancelButton().exists()).toBe(true);
          expect(findSubmitButton().exists()).toBe(false);

          wrapper.setProps({ isLoading: true });
          await nextTick();

          expect(findCancelButton().exists()).toBe(true);
          expect(findSubmitButton().exists()).toBe(false);

          wrapper.setProps({ isLoading: false });
          await nextTick();

          expect(findCancelButton().exists()).toBe(false);
          expect(findSubmitButton().exists()).toBe(true);
        });
      });
    });

    describe('submit', () => {
      const ENTER = 'Enter';

      it('trims the prompt', () => {
        const question = ' foo bar ';
        const expectedPrompt = 'foo bar';
        createComponent({
          propsData: { isChatAvailable: true },
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
          propsData: { isChatAvailable: true },
        });
        setPromptInput(promptStr);
        trigger();
        expect(wrapper.emitted('send-chat-prompt')).toEqual(expectEmitted);
      });

      it('on composition, discards the first enter after composition has ended', async () => {
        createComponent({
          propsData: { isChatAvailable: true },
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
          propsData: { isChatAvailable: true, lastMessage: msgs[msgs.length - 1] ?? null },
        });

        setPromptInput(promptStr);
        clickSubmit();

        await waitForChatSubmission();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[promptStr]]);

        setPromptInput(promptStr);
        clickSubmit();

        await waitForChatSubmission();

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
        const lastMsg = msgs[msgs.length - 1];
        createComponent({
          propsData: { isChatAvailable: true, lastMessage: lastMsg },
        });

        setPromptInput(promptStr);
        clickSubmit();

        await waitForChatSubmission();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[promptStr]]);

        setPromptInput(promptStr);
        clickSubmit();

        await waitForChatSubmission();

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
        createComponent({
          mountFn: mountExtended,
        });
        findChatInputNative().element.value = 'TEST!';
        await findChatInputNative().trigger('input');

        clickSubmit();
        await nextTick();

        expect(focusSpy).toHaveBeenCalledWith(findChatInputNative().element);
      });

      it('restores focus to prompt when isLoading becomes false after sending with focus', async () => {
        createComponent({
          propsData: { isChatAvailable: true },
          mountFn: mountExtended,
        });

        await setFocusAndSubmitMessage('test message');

        const focusSpy = jest.fn();
        jest.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function focusMockImpl() {
          focusSpy(this);
        });

        await wrapper.setProps({ isLoading: true });
        await wrapper.setProps({ isLoading: false });
        await nextTick();

        expect(focusSpy).toHaveBeenCalledWith(findChatInputNative().element);
      });

      it('does not restore focus when isLoading becomes false if input was not focused before send', async () => {
        createComponent({
          propsData: { isLoading: true, isChatAvailable: true },
          mountFn: mountExtended,
        });

        const focusSpy = jest.fn();
        jest.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function focusMockImpl() {
          focusSpy(this);
        });

        await wrapper.setProps({ isLoading: false });
        await nextTick();

        expect(focusSpy).not.toHaveBeenCalled();
      });

      it('restores focus to prompt when isStreaming becomes false after sending with focus', async () => {
        const streamingMessage = { role: 'assistant', chunks: ['partial'], content: undefined };
        const completedMessage = { role: 'assistant', chunks: ['partial'], content: 'done' };
        createComponent({
          propsData: { isChatAvailable: true },
          mountFn: mountExtended,
        });

        await setFocusAndSubmitMessage('test message');

        const focusSpy = jest.fn();
        jest.spyOn(HTMLElement.prototype, 'focus').mockImplementation(function focusMockImpl() {
          focusSpy(this);
        });

        await wrapper.setProps({ lastMessage: streamingMessage });
        await wrapper.setProps({ lastMessage: completedMessage });
        await nextTick();

        expect(focusSpy).toHaveBeenCalledWith(findChatInputNative().element);
      });
    });

    describe('clear', () => {
      it('does not render cancel button on clear', async () => {
        createComponent({
          propsData: { isChatAvailable: true },
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
          propsData: { isChatAvailable: true },
          mountFn: mountExtended,
        });
        setPromptInput(CHAT_NEW_MESSAGE);
        clickSubmit();

        await nextTick();
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });
    });

    describe('reset', () => {
      it('emits the event with the reset prompt', async () => {
        createComponent({
          propsData: { isChatAvailable: true },
          mountFn: mountExtended,
        });

        findChatInputNative().element.value = CHAT_RESET_MESSAGE;
        await findChatInputNative().trigger('input');
        clickSubmit();

        expect(wrapper.emitted('send-chat-prompt')).toEqual([[CHAT_RESET_MESSAGE]]);
        await nextTick();
        expect(findSubmitButton().exists()).toBe(true);
        expect(findCancelButton().exists()).toBe(false);
      });
    });

    describe('cancel', () => {
      it('emits cancel event on cancel button click', async () => {
        createComponent({ propsData: {}, mountFn: mountExtended });
        findChatInputNative().element.value = 'TEST!';
        await findChatInputNative().trigger('input');
        clickSubmit();
        await waitForChatSubmission();

        const cancelButton = findCancelButton();
        expect(cancelButton.exists()).toBe(true);
        await cancelButton.trigger('click');
        expect(wrapper.emitted('chat-cancel')).toHaveLength(1);
      });
    });

    describe('undo/redo methods', () => {
      beforeEach(() => {
        document.execCommand = jest.fn();
        createComponent({ propsData: {}, mountFn: mountExtended });
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
        await findChatInputNative().trigger('keydown', eventOptions);

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

        await findChatInputNative().trigger('keydown', {
          ...eventOptions,
          preventDefault: preventDefaultSpy,
          stopPropagation: stopPropagationSpy,
        });

        expect(preventDefaultSpy).not.toHaveBeenCalled();
        expect(document.execCommand).not.toHaveBeenCalledWith(expectedCommand);

        await findChatInputNative().setValue(expectedCommand);

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
          createComponent({ propsData: {}, mountFn: mountExtended });
          await nextTick();

          expect(wrapper.vm.$refs.prompt).toBeDefined();
          expect(wrapper.vm.$refs.prompt.$el.focus).toEqual(expect.any(Function));
        });
      });
    });
  });

  it('sets max-rows on the textarea to limit auto-grow height', () => {
    createComponent();

    expect(findChatInput().props('maxRows')).toBe(20);
  });

  describe('input actions', () => {
    it('renders the PromptInputActions component', () => {
      createComponent();

      expect(findInputActions().exists()).toBe(true);
    });

    it('disables the input actions when chat is unavailable', () => {
      createComponent({ propsData: { isChatAvailable: false } });

      expect(findInputActions().props('disabled')).toBe(true);
    });

    it('disables the input actions when chatState is disabled', () => {
      createComponent({ propsData: { chatState: { isEnabled: false, reason: 'No credits' } } });

      expect(findInputActions().props('disabled')).toBe(true);
    });

    it('does not disable the input actions when chat is available and enabled', () => {
      createComponent({ propsData: { isChatAvailable: true, chatState: { isEnabled: true } } });

      expect(findInputActions().props('disabled')).toBe(false);
    });

    it('emits web-search-toggled when PromptInputActions toggles web search', async () => {
      createComponent();
      expect(findInputActions().props('webSearchEnabled')).toBe(false);

      await findInputActions().vm.$emit('update:web-search-enabled', true);

      expect(wrapper.emitted('web-search-toggled')).toEqual([[true]]);
    });

    it('reflects webSearchEnabled prop in PromptInputActions', () => {
      createComponent({ propsData: { webSearchEnabled: true } });

      expect(findInputActions().props('webSearchEnabled')).toBe(true);
    });
  });

  describe('thread management', () => {
    describe('prompt clearing race condition fix', () => {
      it('clears prompt before disabling input', async () => {
        createComponent({ mountFn: mountExtended });

        const testPrompt = 'Hello world!';
        findChatInputNative().element.value = testPrompt;
        await findChatInputNative().trigger('input');

        expect(findChatInputNative().attributes('disabled')).toBeUndefined();

        // Submit the prompt
        clickSubmit();

        // - `prompt` has been cleared
        // - `canSubmit` has not yet propagated
        // → Input should be empty but still enabled
        await nextTick();
        expect(findChatInputNative().element.value).toBe('');
        expect(findChatInputNative().attributes('disabled')).toBeUndefined();

        // Vue finishes propagating reactivity (e.g. computed `canSubmit`)
        // → Input is now disabled, still empty
        await waitForChatSubmission();
        expect(findChatInputNative().element.value).toBe('');
        expect(findChatInputNative().attributes('disabled')).toBe('disabled');
      });
    });
  });
});
