import { BufferOverflowError } from 'ee/ai/duo_agentic_chat/websocket/buffer_overflow_error';

describe('BufferOverflowError', () => {
  let error;

  beforeEach(() => {
    error = new BufferOverflowError('message', 1000);
  });

  it('is an Error subclass with its own name', () => {
    expect(error).toBeInstanceOf(BufferOverflowError);
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('BufferOverflowError');
  });

  it('describes the event type and the limit', () => {
    expect(error.message).toBe('Buffer for "message" reached its limit of 1000 events');
  });

  // Exposed as a field so a Sentry report identifies the buffer without
  // anyone having to parse the message.
  it('exposes the event type', () => {
    expect(error.eventType).toBe('message');
  });
});
