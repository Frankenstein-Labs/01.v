import { clarificationQuestionTransformer } from 'ee/ai/duo_agentic_chat/transformers/clarification_question_transformer';

const TOOL_MESSAGE_ID = 'tool-msg-1';

const makeClarificationToolMessage = (overrides = {}) => ({
  message_id: TOOL_MESSAGE_ID,
  message_type: 'tool',
  message_sub_type: 'clarification_question',
  tool_info: {
    name: 'clarification_question',
    args: { options: ['option-a', 'option-b'] },
  },
  content: 'Which option do you prefer?',
  ...overrides,
});

const makeAnswerMessage = ({
  messageId = TOOL_MESSAGE_ID,
  optionId = 'option-a',
  ...overrides
} = {}) => ({
  message_id: 'user-msg-1',
  message_type: 'user',
  message_sub_type: 'clarification_answer',
  content: JSON.stringify({
    message_sub_type: 'clarification_answer',
    selected_option: optionId,
    message_id: messageId,
  }),
  ...overrides,
});

describe('clarificationQuestionTransformer', () => {
  it('removes the answer message when its message_id matches the tool message', () => {
    const messages = [makeClarificationToolMessage(), makeAnswerMessage()];
    const result = clarificationQuestionTransformer(messages);

    expect(result).toHaveLength(1);
    expect(result[0].message_type).toBe('tool');
  });

  it('adds chosen_option_id from the parsed selected_option', () => {
    const messages = [makeClarificationToolMessage(), makeAnswerMessage({ optionId: 'option-b' })];
    const result = clarificationQuestionTransformer(messages);

    expect(result[0].tool_info.args.chosen_option_id).toBe('option-b');
  });

  it('sets chosen_option_id to null when no user message follows the tool message', () => {
    const result = clarificationQuestionTransformer([makeClarificationToolMessage()]);

    expect(result[0].tool_info.args.chosen_option_id).toBeNull();
  });

  it('sets chosen_option_id to "skipped" when a user message follows but does not reference the tool', () => {
    const unrelatedUser = { message_id: 'u1', message_type: 'user', content: 'something else' };
    const result = clarificationQuestionTransformer([
      makeClarificationToolMessage(),
      unrelatedUser,
    ]);

    expect(result[0].tool_info.args.chosen_option_id).toBe('skipped');
  });

  it('preserves existing tool_info.args fields', () => {
    const messages = [makeClarificationToolMessage(), makeAnswerMessage()];
    const result = clarificationQuestionTransformer(messages);

    expect(result[0].tool_info.args.options).toEqual(['option-a', 'option-b']);
  });

  it('sets chosen_option_id to "skipped" when the following user message references a different tool', () => {
    const messages = [
      makeClarificationToolMessage({ message_id: 'tool-1' }),
      makeAnswerMessage({ messageId: 'tool-99' }),
    ];
    const result = clarificationQuestionTransformer(messages);

    expect(result).toHaveLength(2);
    expect(result[0].tool_info.args.chosen_option_id).toBe('skipped');
  });

  it('matches by message_id even when non-user messages appear between tool and answer', () => {
    const messages = [
      makeClarificationToolMessage(),
      { message_id: 'agent-1', message_type: 'agent', content: 'thinking...' },
      makeAnswerMessage({ messageId: TOOL_MESSAGE_ID, message_id: 'user-1' }),
    ];

    const result = clarificationQuestionTransformer(messages);

    expect(result).toHaveLength(2);
    expect(result[0].tool_info.args.chosen_option_id).toBe('option-a');
  });

  it('handles multiple sequential pairs', () => {
    const messages = [
      makeClarificationToolMessage({ message_id: 'tool-1' }),
      makeAnswerMessage({ messageId: 'tool-1', optionId: 'opt-1', message_id: 'user-1' }),
      makeClarificationToolMessage({ message_id: 'tool-2' }),
      makeAnswerMessage({ messageId: 'tool-2', optionId: 'opt-2', message_id: 'user-2' }),
    ];

    const result = clarificationQuestionTransformer(messages);

    expect(result).toHaveLength(2);
    expect(result[0].tool_info.args.chosen_option_id).toBe('opt-1');
    expect(result[1].tool_info.args.chosen_option_id).toBe('opt-2');
  });

  it('ignores a user message that appears before the tool message', () => {
    const messages = [
      makeAnswerMessage({ messageId: TOOL_MESSAGE_ID, message_id: 'user-before' }),
      makeClarificationToolMessage(),
    ];

    const result = clarificationQuestionTransformer(messages);

    expect(result).toHaveLength(2);
    expect(result[1].tool_info.args.chosen_option_id).toBeNull();
  });

  it('does not mutate the original messages array', () => {
    const messages = [makeClarificationToolMessage(), makeAnswerMessage()];
    const copy = [...messages];

    clarificationQuestionTransformer(messages);

    expect(messages).toEqual(copy);
  });
});
