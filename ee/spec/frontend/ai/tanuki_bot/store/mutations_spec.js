import * as types from 'ee/ai/tanuki_bot/store/mutation_types';
import mutations from 'ee/ai/tanuki_bot/store/mutations';
import createState from 'ee/ai/tanuki_bot/store/state';
import {
  GENIE_CHAT_MODEL_ROLES,
  CHAT_MESSAGE_TYPES,
  DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
} from 'ee/ai/constants';
import { MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE, MOCK_FAILING_USER_MESSAGE } from '../mock_data';

describe('GitLab Duo Chat Store Mutations', () => {
  let state;
  beforeEach(() => {
    state = createState();
  });

  describe('ADD_MESSAGE', () => {
    const requestId = '123';
    const userMessageWithRequestId = { ...MOCK_USER_MESSAGE, requestId };

    // Mock tool message for testing the new tool role handling
    const MOCK_TOOL_MESSAGE = {
      content: 'Using tool to search issues',
      role: GENIE_CHAT_MODEL_ROLES.tool,
      tool_info: { name: 'search_issues' },
      requestId,
    };

    describe('system message', () => {
      it.each(['system', 'SYSTEM'])(
        'ignores the messages with role="%s" and does not populate the state',
        (role) => {
          const messageData = {
            ...MOCK_USER_MESSAGE,
            role,
          };
          mutations[types.ADD_MESSAGE](state, messageData);
          expect(state.messages).toStrictEqual([]);
        },
      );
    });

    describe('when there is no message with the same requestId', () => {
      it.each`
        messageData                                                                              | expectedState
        ${MOCK_USER_MESSAGE}                                                                     | ${[MOCK_USER_MESSAGE]}
        ${MOCK_FAILING_USER_MESSAGE}                                                             | ${[MOCK_FAILING_USER_MESSAGE]}
        ${MOCK_TOOL_MESSAGE}                                                                     | ${[MOCK_TOOL_MESSAGE]}
        ${{ content: 'foo', role: GENIE_CHAT_MODEL_ROLES.assistant, chunkId: undefined }}        | ${[{ content: 'foo', role: GENIE_CHAT_MODEL_ROLES.assistant, chunkId: undefined }]}
        ${{ content: 'foo', source: 'bar', role: GENIE_CHAT_MODEL_ROLES.assistant, chunkId: 1 }} | ${[{ content: 'foo', source: 'bar', role: GENIE_CHAT_MODEL_ROLES.assistant, chunkId: 1 }]}
        ${{}}                                                                                    | ${[]}
        ${undefined}                                                                             | ${[]}
      `('pushes a message object to state', ({ messageData, expectedState }) => {
        mutations[types.ADD_MESSAGE](state, messageData);
        expect(state.messages).toStrictEqual(expectedState);
      });
    });

    describe('when there is a message with the same requestId', () => {
      const updatedContent = 'Updated content';

      it('updates the correct message based on the role', () => {
        state.messages.push(
          {
            ...MOCK_USER_MESSAGE,
            requestId,
          },
          {
            ...MOCK_TANUKI_MESSAGE,
            requestId,
          },
        );
        mutations[types.ADD_MESSAGE](state, {
          requestId,
          role: MOCK_TANUKI_MESSAGE.role,
          content: updatedContent,
        });
        expect(state.messages).toHaveLength(2);
        expect(state.messages).toStrictEqual([
          {
            ...MOCK_USER_MESSAGE,
            requestId,
          },
          {
            ...MOCK_TANUKI_MESSAGE,
            requestId,
            content: updatedContent,
          },
        ]);
      });

      describe('when the message is of the same role', () => {
        it('updates the message object if it is of exactly the same role', () => {
          state.messages.push({ ...MOCK_USER_MESSAGE, requestId });
          mutations[types.ADD_MESSAGE](state, {
            ...MOCK_USER_MESSAGE,
            requestId,
            content: updatedContent,
          });
          expect(state.messages).toHaveLength(1);
          expect(state.messages).toStrictEqual([
            {
              ...MOCK_USER_MESSAGE,
              requestId,
              content: updatedContent,
            },
          ]);
        });

        it('still updates despite the capitalization differences in the role', () => {
          state.messages.push({
            ...MOCK_USER_MESSAGE,
            requestId,
            role: MOCK_USER_MESSAGE.role.toLowerCase(),
          });
          mutations[types.ADD_MESSAGE](state, {
            requestId,
            role: MOCK_USER_MESSAGE.role.toUpperCase(),
            content: updatedContent,
          });
          expect(state.messages).toHaveLength(1);
          expect(state.messages).toStrictEqual([
            {
              ...MOCK_USER_MESSAGE,
              requestId,
              role: MOCK_USER_MESSAGE.role.toUpperCase(),
              content: updatedContent,
            },
          ]);
        });
      });

      it('correctly injects a new ASSISTANT message right after the corresponding USER message', () => {
        const promptRequestId = '456';
        const userPrompt = {
          ...MOCK_USER_MESSAGE,
          requestId: promptRequestId,
        };
        const responseToPrompt = {
          ...MOCK_TANUKI_MESSAGE,
          requestId: promptRequestId,
        };
        state.messages.push(userPrompt, userMessageWithRequestId);

        mutations[types.ADD_MESSAGE](state, responseToPrompt);
        expect(state.messages).toHaveLength(3);
        expect(state.messages).toStrictEqual([
          userPrompt,
          expect.objectContaining(responseToPrompt),
          userMessageWithRequestId,
        ]);
      });

      it('updates the pending user message when it has the pending requestId and matching content', () => {
        const pendingUserMessage = {
          content: 'Initial content',
          role: GENIE_CHAT_MODEL_ROLES.user,
          requestId: DUO_AGENTIC_CHAT_PENDING_USER_MESSAGE_ID,
        };

        state.messages.push(pendingUserMessage);

        const updatedUserMessage = {
          content: 'Initial content',
          role: GENIE_CHAT_MODEL_ROLES.user,
          requestId: 'actual-request-id',
        };

        mutations[types.ADD_MESSAGE](state, updatedUserMessage);

        expect(state.messages).toHaveLength(1);
        expect(state.messages[0]).toEqual({
          content: 'Initial content',
          role: GENIE_CHAT_MODEL_ROLES.user,
          requestId: 'actual-request-id',
        });
      });

      it('updates an existing tool message with the same requestId', () => {
        state.messages.push({ ...MOCK_TOOL_MESSAGE });

        const updatedToolMessage = {
          ...MOCK_TOOL_MESSAGE,
          content: 'Updated tool message',
          tool_info: {
            name: 'search_issues',
            result: 'Found 5 issues',
          },
        };

        mutations[types.ADD_MESSAGE](state, updatedToolMessage);

        expect(state.messages).toHaveLength(1);
        expect(state.messages[0]).toEqual(updatedToolMessage);
      });
    });

    describe('tool messages', () => {
      it('adds a new tool message to the state', () => {
        mutations[types.ADD_MESSAGE](state, MOCK_TOOL_MESSAGE);

        expect(state.messages).toHaveLength(1);
        expect(state.messages[0]).toEqual(MOCK_TOOL_MESSAGE);
      });

      it('preserves tool_info when updating an existing tool message', () => {
        const initialToolMessage = {
          ...MOCK_TOOL_MESSAGE,
          tool_info: { name: 'search_issues' },
        };

        state.messages.push(initialToolMessage);

        const updatedToolMessage = {
          ...MOCK_TOOL_MESSAGE,
          content: 'Updated tool content',
          tool_info: {
            name: 'search_issues',
            result: 'Found 5 issues',
          },
        };

        mutations[types.ADD_MESSAGE](state, updatedToolMessage);

        expect(state.messages).toHaveLength(1);
        expect(state.messages[0].content).toBe('Updated tool content');
        expect(state.messages[0].tool_info).toEqual({
          name: 'search_issues',
          result: 'Found 5 issues',
        });
      });

      it('adds a tool message with message_type property', () => {
        const toolMessageWithType = {
          ...MOCK_TOOL_MESSAGE,
          message_type: 'tool',
        };

        mutations[types.ADD_MESSAGE](state, toolMessageWithType);

        expect(state.messages).toHaveLength(1);
        expect(state.messages[0].message_type).toBe('tool');
      });
    });
  });

  describe('ADD_TOOL_MESSAGE', () => {
    const toolMessage = {
      ...MOCK_USER_MESSAGE,
      role: GENIE_CHAT_MODEL_ROLES.system,
      type: CHAT_MESSAGE_TYPES.tool,
    };
    it.each`
      desc              | message              | expectedState
      ${'sets'}         | ${toolMessage}       | ${toolMessage}
      ${'does not set'} | ${MOCK_USER_MESSAGE} | ${''}
    `('$desc the `toolMessage` when message is $message', ({ message, expectedState }) => {
      mutations[types.ADD_TOOL_MESSAGE](state, message);

      expect(state.toolMessage).toStrictEqual(expectedState);
    });
  });

  describe('CLEAN_MESSAGES', () => {
    it('removes all messages from chat', () => {
      state.messages.push(MOCK_USER_MESSAGE, MOCK_TANUKI_MESSAGE);

      mutations[types.CLEAN_MESSAGES](state);
      expect(state.messages).toStrictEqual([]);
    });
  });
});
