import {
  clearDuoChatCommands,
  sendDuoChatCommand,
  openDuoChatWithAgent,
  generateEventLabelFromText,
  utils,
  setAgenticMode,
  saveDuoAgenticModePreference,
  focusDuoChatInput,
  initializeChatMode,
  agentAvatarEntityId,
} from 'ee/ai/utils';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { setCookie, getCookie } from '~/lib/utils/common_utils';
import { saveStorageValue } from '~/lib/utils/local_storage';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  CHAT_MODES,
} from 'ee/ai/tanuki_bot/constants';
import { eventHub, SHOW_NEW_CHAT } from 'ee/ai/events/panel';

jest.mock('~/lib/utils/common_utils', () => ({
  setCookie: jest.fn(),
  getCookie: jest.fn(),
}));

jest.mock('~/lib/utils/local_storage', () => ({
  getStorageValue: jest.fn(() => ({ exists: false })),
  saveStorageValue: jest.fn(),
}));

describe('AI Utils', () => {
  describe('concatStreamedChunks', () => {
    it.each`
      input                        | expected
      ${[]}                        | ${''}
      ${['']}                      | ${''}
      ${[undefined, 'foo']}        | ${''}
      ${['foo', 'bar']}            | ${'foobar'}
      ${['foo', '', 'bar']}        | ${'foo'}
      ${['foo', undefined, 'bar']} | ${'foo'}
      ${['foo', ' ', 'bar']}       | ${'foo bar'}
      ${['foo', 'bar', undefined]} | ${'foobar'}
    `('correctly concatenates streamed chunks', ({ input, expected }) => {
      expect(utils.concatStreamedChunks(input)).toBe(expected);
    });
  });

  describe('sendDuoChatCommand', () => {
    describe('arguments validation', () => {
      it.each`
        question       | resourceId
        ${null}        | ${null}
        ${null}        | ${'1'}
        ${'/feedback'} | ${null}
      `(
        'throws an error if args are question: $question, resourceId: $resourceId',
        ({ question, resourceId }) => {
          expect(() => {
            sendDuoChatCommand({ question, resourceId });
          }).toThrow('Both arguments `question` and `resourceId` are required');
        },
      );

      it('does not throw with valid arguments', () => {
        expect(() => {
          sendDuoChatCommand({ question: '/feedback', resourceId: '1' });
        }).not.toThrow();
      });
    });

    describe('mode preservation', () => {
      let originalRequestIdleCallback;

      beforeEach(() => {
        originalRequestIdleCallback = window.requestIdleCallback;
        window.requestIdleCallback = (callback) => callback();

        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
        duoChatGlobalState.commands = [];

        jest.clearAllMocks();
      });

      afterEach(() => {
        window.requestIdleCallback = originalRequestIdleCallback;
      });

      it('preserves classic mode when sending a command', () => {
        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;

        const command = { question: '/help', resourceId: '123' };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.CLASSIC);

        expect(setCookie).not.toHaveBeenCalled();
      });

      it('preserves agentic mode when sending a command', () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

        const command = { question: '/help', resourceId: '123' };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);

        expect(setCookie).not.toHaveBeenCalled();
      });

      it('uses slash command in classic mode', () => {
        duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;

        const command = {
          question: '/help',
          resourceId: '123',
          agenticPrompt: 'help me with this',
        };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.commands).toContainEqual({
          question: '/help',
          resourceId: '123',
          variables: {},
        });
      });

      it('uses agenticPrompt in agentic mode when provided', () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

        const command = {
          question: '/help',
          resourceId: '123',
          agenticPrompt: 'help me with this',
        };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.commands).toContainEqual({
          question: 'help me with this',
          resourceId: '123',
          variables: {},
        });
      });

      it('falls back to slash command in agentic mode when agenticPrompt is not provided', () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

        const command = { question: '/help', resourceId: '123' };
        sendDuoChatCommand(command);

        expect(duoChatGlobalState.commands).toContainEqual({
          question: '/help',
          resourceId: '123',
          variables: {},
        });
      });

      it('does not change state when command validation fails', () => {
        duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

        expect(() => {
          sendDuoChatCommand({ question: null, resourceId: '123' });
        }).toThrow('Both arguments `question` and `resourceId` are required');

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
        expect(setCookie).not.toHaveBeenCalled();
      });

      it('preserves current mode for different command types', () => {
        const commands = [
          { question: '/troubleshoot', resourceId: '1', agenticPrompt: 'troubleshoot this' },
          { question: '/help', resourceId: '2', variables: { foo: 'bar' } },
          { question: 'Custom question', resourceId: '3' },
        ];

        commands.forEach((command) => {
          duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;

          sendDuoChatCommand(command);

          expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
        });

        expect(setCookie).not.toHaveBeenCalled();
      });
    });

    describe('commands', () => {
      const newCommand = { question: 'new', resourceId: '2', variables: { otherStuff: '' } };
      let originalRequestIdleCallback;

      beforeEach(() => {
        originalRequestIdleCallback = window.requestIdleCallback;
        window.requestIdleCallback = (callback) => callback();
      });

      afterEach(() => {
        duoChatGlobalState.commands = [];
        window.requestIdleCallback = originalRequestIdleCallback;
      });

      it.each`
        commands | text
        ${[]}    | ${'in an empty array'}
        ${[]}    | ${'in an array with items'}
      `('Adds new command to existing commands $text', ({ commands }) => {
        duoChatGlobalState.commands = [...commands];
        sendDuoChatCommand(newCommand);
        expect(duoChatGlobalState.commands).toEqual([...commands, newCommand]);
      });
    });
  });

  describe('openDuoChatWithAgent', () => {
    let originalRequestIdleCallback;

    beforeEach(() => {
      originalRequestIdleCallback = window.requestIdleCallback;
      window.requestIdleCallback = (callback) => callback();

      duoChatGlobalState.commands = [];
    });

    afterEach(() => {
      window.requestIdleCallback = originalRequestIdleCallback;
      duoChatGlobalState.commands = [];
    });

    describe('argument validation', () => {
      it.each`
        agent              | resourceId
        ${null}            | ${null}
        ${null}            | ${'1'}
        ${{ name: 'Foo' }} | ${null}
      `('throws when agent: $agent, resourceId: $resourceId', ({ agent, resourceId }) => {
        expect(() => openDuoChatWithAgent({ agent, resourceId })).toThrow(
          'Both arguments `agent` and `resourceId` are required',
        );
      });

      it('does not throw with valid arguments', () => {
        expect(() =>
          openDuoChatWithAgent({ agent: { name: 'Planner' }, resourceId: '1' }),
        ).not.toThrow();
      });
    });

    it('enables agentic mode', () => {
      openDuoChatWithAgent({ agent: { name: 'Planner' }, resourceId: '1' });

      expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
    });

    it('emits SHOW_NEW_CHAT to open the chat panel', () => {
      const emitSpy = jest.spyOn(eventHub, '$emit');
      openDuoChatWithAgent({ agent: { name: 'Planner' }, resourceId: '1' });

      expect(emitSpy).toHaveBeenCalledWith(SHOW_NEW_CHAT);
    });

    it('pushes a command with autoSend: false', () => {
      openDuoChatWithAgent({ agent: { name: 'Planner' }, resourceId: '1' });

      expect(duoChatGlobalState.commands).toContainEqual(
        expect.objectContaining({ autoSend: false }),
      );
    });

    it('includes the agent in the command', () => {
      const agent = { name: 'Planner' };
      openDuoChatWithAgent({ agent, resourceId: '1' });

      expect(duoChatGlobalState.commands).toContainEqual(expect.objectContaining({ agent }));
    });

    it('includes welcomeMessage in the command when provided', () => {
      openDuoChatWithAgent({
        agent: { name: 'Planner' },
        resourceId: '1',
        welcomeMessage: 'Hello!',
      });

      expect(duoChatGlobalState.commands).toContainEqual(
        expect.objectContaining({ welcomeMessage: 'Hello!' }),
      );
    });

    it('includes predefinedPrompts in the command when provided', () => {
      const prompts = ['How do I fork a project?', 'What is a merge request?'];
      openDuoChatWithAgent({
        agent: { name: 'Planner' },
        resourceId: '1',
        predefinedPrompts: prompts,
      });

      expect(duoChatGlobalState.commands).toContainEqual(
        expect.objectContaining({ predefinedPrompts: prompts }),
      );
    });

    it('defaults welcomeMessage, predefinedPrompts, and additionalContext to null when not provided', () => {
      openDuoChatWithAgent({ agent: { name: 'Planner' }, resourceId: '1' });

      expect(duoChatGlobalState.commands).toContainEqual(
        expect.objectContaining({
          welcomeMessage: null,
          predefinedPrompts: null,
          additionalContext: null,
        }),
      );
    });

    it('includes additionalContext in the command when provided', () => {
      const additionalContext = [
        { category: 'form_context', content: '{"form_id":"my-form"}', metadata: '{}' },
      ];
      openDuoChatWithAgent({ agent: { name: 'Planner' }, resourceId: '1', additionalContext });

      expect(duoChatGlobalState.commands).toContainEqual(
        expect.objectContaining({ additionalContext }),
      );
    });
  });

  describe('focusDuoChatInput', () => {
    beforeEach(() => {
      duoChatGlobalState.focusChatInput = false;
    });

    it('opens duo chat and updates the focusChatInput state to true', () => {
      focusDuoChatInput();

      expect(duoChatGlobalState.focusChatInput).toBe(true);
    });
  });

  describe('clearDuoChatCommands', () => {
    beforeEach(() => {
      duoChatGlobalState.commands = [
        { question: '/troubleshoot', resourceId: '1' },
        { question: '/action', resourceId: '2' },
      ];
    });

    afterEach(() => {
      duoChatGlobalState.commands = [];
    });

    it('clears all existing commands', () => {
      clearDuoChatCommands();
      expect(duoChatGlobalState.commands).toEqual([]);
    });
  });

  describe('generateEventLabelFromText', () => {
    it.each([
      {
        input: 'What are the main points from this MR discussion?',
        expected: 'what_are_the_main_points_from_this_mr_discussion',
      },
      {
        input: "What's going on with this code?!",
        expected: 'whats_going_on_with_this_code',
      },
      {
        input:
          'A very long string that should be truncated because it exceeds the maximum length of fifty characters',
        expected: 'a_very_long_string_that_should_be_truncated_becaus',
      },
    ])('converts "$input" to "$expected"', ({ input, expected }) => {
      expect(generateEventLabelFromText(input)).toBe(expected);
    });
  });

  describe('saveDuoAgenticModePreference', () => {
    it.each`
      isAgenticMode
      ${true}
      ${false}
    `('calls setCookie with $isAgenticMode value', ({ isAgenticMode }) => {
      saveDuoAgenticModePreference(isAgenticMode);

      expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
        expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
      });
      expect(setCookie).toHaveBeenCalledTimes(1);
    });

    it.each`
      isAgenticMode
      ${true}
      ${false}
    `('calls saveStorageValue with $isAgenticMode value', ({ isAgenticMode }) => {
      saveDuoAgenticModePreference(isAgenticMode);

      expect(saveStorageValue).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, isAgenticMode);
      expect(saveStorageValue).toHaveBeenCalledTimes(1);
    });

    it('saves to both cookie and localStorage', () => {
      saveDuoAgenticModePreference(true);

      expect(setCookie).toHaveBeenCalled();
      expect(saveStorageValue).toHaveBeenCalled();
    });
  });

  describe('setAgenticMode', () => {
    beforeEach(() => {
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      jest.clearAllMocks();
    });

    afterEach(() => {
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
    });

    describe('when agenticMode is true', () => {
      it('does not save to cookie by default', () => {
        setAgenticMode({ agenticMode: true });

        expect(setCookie).not.toHaveBeenCalled();
      });

      it('saves to cookie when saveCookie is true', () => {
        setAgenticMode({ agenticMode: true, saveCookie: true });

        expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, true, {
          expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
        });
        expect(setCookie).toHaveBeenCalledTimes(1);
      });
    });

    describe('when agenticMode is false', () => {
      it('does not save to cookie by default', () => {
        setAgenticMode({ agenticMode: false });

        expect(setCookie).not.toHaveBeenCalled();
      });

      it('saves to cookie when saveCookie is true', () => {
        setAgenticMode({ agenticMode: false, saveCookie: true });

        expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_MODE_COOKIE, false, {
          expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
        });
        expect(setCookie).toHaveBeenCalledTimes(1);
      });
    });

    describe('default parameters', () => {
      it('defaults saveCookie to false when only agenticMode is provided', () => {
        setAgenticMode({ agenticMode: false });

        expect(setCookie).not.toHaveBeenCalled();
      });
    });

    describe('chatMode', () => {
      it('sets chatMode to AGENTIC when agenticMode is true', () => {
        setAgenticMode({ agenticMode: true });

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });

      it('sets chatMode to CLASSIC when agenticMode is false', () => {
        setAgenticMode({ agenticMode: false });

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.CLASSIC);
      });
    });
  });

  describe('sendDuoChatCommand routing', () => {
    let originalRequestIdleCallback;
    let originalGon;

    beforeEach(() => {
      originalRequestIdleCallback = window.requestIdleCallback;
      window.requestIdleCallback = (callback) => callback();
      originalGon = window.gon;

      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      duoChatGlobalState.commands = [];

      jest.clearAllMocks();
    });

    afterEach(() => {
      window.requestIdleCallback = originalRequestIdleCallback;
      window.gon = originalGon;
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
    });

    it('emits SHOW_NEW_CHAT in classic mode', () => {
      const emitSpy = jest.spyOn(eventHub, '$emit');
      duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
      sendDuoChatCommand({ question: '/help', resourceId: '123' });

      expect(emitSpy).toHaveBeenCalledWith(SHOW_NEW_CHAT);
    });

    it('emits SHOW_NEW_CHAT in agentic mode', () => {
      const emitSpy = jest.spyOn(eventHub, '$emit');
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      sendDuoChatCommand({ question: '/help', resourceId: '123' });

      expect(emitSpy).toHaveBeenCalledWith(SHOW_NEW_CHAT);
    });

    it('preserves the current mode', () => {
      duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
      sendDuoChatCommand({ question: '/help', resourceId: '123' });

      expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
    });
  });

  describe('chatMode initialization from cookie', () => {
    afterEach(() => {
      window.gon = {};
    });

    describe('when agentic chat is always enabled', () => {
      beforeEach(() => {
        window.gon = { features: {} };
      });

      it('defaults to agentic mode when no cookie is set', () => {
        getCookie.mockReturnValue(undefined);

        initializeChatMode();

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });

      it('defaults to agentic mode when cookie is empty string', () => {
        getCookie.mockReturnValue('');

        initializeChatMode();

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });

      it('uses classic mode when cookie is explicitly set to false', () => {
        getCookie.mockReturnValue('false');

        initializeChatMode();

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.CLASSIC);
      });

      it('uses agentic mode when cookie is set to true', () => {
        getCookie.mockReturnValue('true');

        initializeChatMode();

        expect(duoChatGlobalState.chatMode).toBe(CHAT_MODES.AGENTIC);
      });
    });
  });

  describe('agentAvatarEntityId', () => {
    it('returns the numeric record id from a numeric GraphQL global id', () => {
      expect(agentAvatarEntityId('gid://gitlab/Ai::Catalog::Item/123')).toBe(123);
    });

    it('hashes a non-numeric (slug) id into a stable non-negative integer so the color is not NaN', () => {
      const result = agentAvatarEntityId('gid://gitlab/Ai::FoundationalChatAgent/agent-v1');

      expect(Number.isInteger(result)).toBe(true);
      expect(result).toBeGreaterThanOrEqual(0);
    });
  });
});
