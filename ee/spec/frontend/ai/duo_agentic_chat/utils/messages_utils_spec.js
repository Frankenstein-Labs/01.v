import { getMessagesToProcess } from 'ee/ai/duo_agentic_chat/utils/messages_utils';
import { MOCK_CHAT_MESSAGES } from './mock_data';

const initialMessageId = null;

describe('Messages_utils', () => {
  describe('getMessagesToProcess', () => {
    describe('default state', () => {
      it.each`
        desc                  | value
        ${'"undefined"'}      | ${undefined}
        ${'"an empty array"'} | ${[]}
      `('returns empty Array when `messages` is %desc', ({ value }) => {
        expect(getMessagesToProcess(value)).toEqual({
          toProcess: [],
          lastProcessedMessageId: initialMessageId,
        });
      });

      it('returns all messages on initial state', () => {
        expect(getMessagesToProcess([MOCK_CHAT_MESSAGES.prompt], initialMessageId)).toEqual({
          toProcess: [MOCK_CHAT_MESSAGES.prompt],
          lastProcessedMessageId: MOCK_CHAT_MESSAGES.prompt.message_id,
        });
      });
    });

    describe('updating the existing messages', () => {
      const currentMessages = [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming];

      it('returns single message matching the lastProcessedMessageId', () => {
        const lastProcessedMessageId = currentMessages[currentMessages.length - 1].message_id; // `agentStreaming` is the last processed

        const incomingMessages = [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentComplete];

        expect(getMessagesToProcess(incomingMessages, lastProcessedMessageId)).toEqual({
          toProcess: [incomingMessages.at(-1)], // only the last agentComplete should be processed
          lastProcessedMessageId: MOCK_CHAT_MESSAGES.agentComplete.message_id, // agentComplete replaces the agentStreaming inline
        });
      });

      it('when existing message is replaced with completely different message at the same index', () => {
        const lastProcessedMessageId = currentMessages[currentMessages.length - 1].message_id; // `agentStreaming` is the last processed

        const incomingMessages = [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.tool];

        // When the lastProcessedMessageId (1) is not found in the incoming messages,
        // the function falls back to processing all messages from the beginning
        expect(getMessagesToProcess(incomingMessages, lastProcessedMessageId)).toEqual({
          toProcess: incomingMessages, // all messages are processed since message_id 1 is not found
          lastProcessedMessageId: MOCK_CHAT_MESSAGES.tool.message_id,
        });
      });

      it('returns all messages from lastProcessedMessageId onwards including the last processed message', () => {
        const lastProcessedMessageId = currentMessages[currentMessages.length - 1].message_id; // `agentStreaming` is the last processed

        const incomingMessages = [
          MOCK_CHAT_MESSAGES.user,
          MOCK_CHAT_MESSAGES.agentComplete,
          MOCK_CHAT_MESSAGES.tool,
          MOCK_CHAT_MESSAGES.request,
        ];

        expect(getMessagesToProcess(incomingMessages, lastProcessedMessageId)).toEqual({
          toProcess: [
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.request,
          ], // only the last agentComplete should be processed
          lastProcessedMessageId: MOCK_CHAT_MESSAGES.request.message_id,
        });
      });
    });

    describe('full cycle workflow', () => {
      it('returns correct messages on every step of a complex workflow', () => {
        // Initial user prompt
        let lastProcessedMessageId;
        let toProcess;
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.prompt],
          initialMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.prompt]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.prompt.message_id);

        // User prompt returned in the checkpoint event
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.user]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.user.message_id);

        // Agent starts to stream
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.agentStreaming.message_id);

        // Streaming continues with a new chunk
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentStreaming1],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([
          MOCK_CHAT_MESSAGES.agentStreaming1, // at this point user doesn't need to be processed again
        ]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.agentStreaming1.message_id);

        // Streaming is done and the complete agent message arrived in the checkpoint event
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentComplete],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.agentComplete]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.agentComplete.message_id);

        // A tool runs automatically to get information that doesn't require approval like
        // fetching a project information
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [MOCK_CHAT_MESSAGES.user, MOCK_CHAT_MESSAGES.agentComplete, MOCK_CHAT_MESSAGES.tool],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.agentComplete, MOCK_CHAT_MESSAGES.tool]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.tool.message_id);

        // Agent starts responding with additional context from the tool
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.agent2Streaming1,
          ],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.tool, MOCK_CHAT_MESSAGES.agent2Streaming1]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.agent2Streaming1.message_id);

        // Agent streaming continues
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.agent2Streaming2,
          ],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.agent2Streaming2]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.agent2Streaming2.message_id);

        // Sometimes, agent streamed response gets replaced with a request, instead of sending the
        // complete agent message.
        // Keep in mind that the agent message will still stay on the screen - message with the same
        // requestID but another message_type is still considered a new message.
        // So, no messages disappearing in the UI!
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.request,
          ],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([MOCK_CHAT_MESSAGES.request]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.request.message_id);

        // User approves request, but tool fails. In this case, the checkpoint event returns 2 messages:
        // - a tool message with `status: "failure"`
        // - a new agent message with some explanation or next step
        ({ toProcess, lastProcessedMessageId } = getMessagesToProcess(
          [
            MOCK_CHAT_MESSAGES.user,
            MOCK_CHAT_MESSAGES.agentComplete,
            MOCK_CHAT_MESSAGES.tool,
            MOCK_CHAT_MESSAGES.request,
            MOCK_CHAT_MESSAGES.tool3Fail[0],
            MOCK_CHAT_MESSAGES.tool3Fail[1],
          ],
          lastProcessedMessageId,
        ));
        expect(toProcess).toEqual([
          MOCK_CHAT_MESSAGES.request,
          MOCK_CHAT_MESSAGES.tool3Fail[0],
          MOCK_CHAT_MESSAGES.tool3Fail[1],
        ]);
        expect(lastProcessedMessageId).toBe(MOCK_CHAT_MESSAGES.tool3Fail[1].message_id);
      });
    });
  });
});
