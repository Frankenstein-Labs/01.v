import {
  RECONNECT_TRIGGERS,
  logStreamClose,
  logStreamReconnect,
  reportStreamClose,
} from 'ee/ai/duo_agentic_chat/observability/stream_close_reporting';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils', () => ({
  captureExceptionForDuoChat: jest.fn(),
}));

describe('stream close reporting', () => {
  let consoleInfo;

  beforeEach(() => {
    consoleInfo = jest.spyOn(console, 'info').mockImplementation(() => {});
  });

  describe('logStreamClose', () => {
    // The point of the console line is that it is unconditional: "it just
    // stopped" looks the same to a user whichever code produced it.
    it.each([
      ['a normal close', { code: 1000, category: 'normal', retryable: false, expected: true }],
      ['a server restart', { code: 1001, category: 'going_away', retryable: true, expected: true }],
      [
        'a rejected request',
        { code: 4400, category: 'invalid_request', retryable: false, expected: false },
      ],
      ['an unknown code', { code: 1006, category: 'error', retryable: true, expected: false }],
    ])('logs %s', (_, event) => {
      logStreamClose(event);

      expect(consoleInfo).toHaveBeenCalledWith(
        '[duo-chat][stream] closed',
        expect.objectContaining({ code: event.code, category: event.category }),
      );
    });

    it('reports a missing reason as null rather than an empty string', () => {
      logStreamClose({ code: 1000, category: 'normal', retryable: false, reason: '' });

      expect(consoleInfo).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({ reason: null }),
      );
    });

    it('never sends a close to Sentry by itself', () => {
      logStreamClose({ code: 4400, category: 'invalid_request', expected: false });

      expect(captureExceptionForDuoChat).not.toHaveBeenCalled();
    });
  });

  describe('logStreamReconnect', () => {
    it('logs why it is reconnecting, the attempt, and the delay it will wait', () => {
      logStreamReconnect({
        trigger: RECONNECT_TRIGGERS.RETRYABLE_CLOSE,
        consecutiveFailures: 2,
        maxRetries: 3,
        delay: 1500,
      });

      expect(consoleInfo).toHaveBeenCalledWith('[duo-chat][stream] reconnecting', {
        trigger: 'retryable_close',
        consecutiveFailures: 2,
        maxRetries: 3,
        delay: 1500,
      });
    });

    // Otherwise a requested reconnect is indistinguishable from an automatic one
    // that happened to be quick.
    it('distinguishes a requested reconnect', () => {
      logStreamReconnect({
        trigger: RECONNECT_TRIGGERS.REQUESTED,
        consecutiveFailures: 3,
        maxRetries: 3,
        delay: 0,
      });

      expect(consoleInfo).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({ trigger: 'requested', delay: 0 }),
      );
    });

    it('does not report a reconnect to Sentry', () => {
      logStreamReconnect({ consecutiveFailures: 1, maxRetries: 3, delay: 1000 });

      expect(captureExceptionForDuoChat).not.toHaveBeenCalled();
    });
  });

  describe('reportStreamClose', () => {
    // These are outcomes, not faults. Reporting them buries the ones that matter.
    it.each([
      ['a normal shutdown', { code: 1000, category: 'normal', expected: true }],
      ['a server restart', { code: 1001, category: 'going_away', expected: true }],
      ['being out of credits', { code: 1008, category: 'policy_violation', expected: true }],
      ['another tab streaming', { code: 1013, category: 'try_again_later', expected: true }],
    ])('stays quiet about %s', (_, event) => {
      reportStreamClose(event);

      expect(captureExceptionForDuoChat).not.toHaveBeenCalled();
    });

    it.each([
      ['a request the backend rejected', { code: 4400, category: 'invalid_request' }],
      ['a code we do not recognise', { code: 1011, category: 'error' }],
    ])('reports %s', (_, event) => {
      reportStreamClose({ ...event, expected: false });

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(
        expect.objectContaining({
          message: `Duo Chat stream closed with ${event.code} (${event.category})`,
        }),
        expect.objectContaining({
          tags: { duo_chat_stream_close: event.category },
          extra: expect.objectContaining({ code: event.code, retriesExhausted: false }),
        }),
      );
    });

    it('passes an Error, so Sentry has a stack to group on', () => {
      reportStreamClose({ code: 4400, category: 'invalid_request', expected: false });

      const [reported] = captureExceptionForDuoChat.mock.calls[0];
      expect(reported).toBeInstanceOf(Error);
    });

    // Recovery is what made a transient close ignorable; with none left, even a
    // routine server restart means the conversation is stuck.
    it('reports an otherwise expected close once retries are exhausted', () => {
      reportStreamClose(
        { code: 1001, category: 'going_away', expected: true },
        { retriesExhausted: true },
      );

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Duo Chat stream could not be recovered after close 1001 (going_away)',
        }),
        expect.objectContaining({ extra: expect.objectContaining({ retriesExhausted: true }) }),
      );
    });

    it('includes the close reason when the server gave one', () => {
      reportStreamClose({
        code: 1008,
        category: 'policy_violation',
        expected: false,
        reason: 'ENUM_USAGE_BILLING_FORBIDDEN',
      });

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(
        expect.any(Error),
        expect.objectContaining({
          extra: expect.objectContaining({ reason: 'ENUM_USAGE_BILLING_FORBIDDEN' }),
        }),
      );
    });
  });
});
