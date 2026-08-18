import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';

jest.mock('~/sentry/sentry_browser_wrapper');

describe('duo_agentic_chat/observability/sentry_utils', () => {
  describe('captureExceptionForDuoChat', () => {
    const error = new Error('something went wrong');

    it('forwards the error to Sentry', () => {
      captureExceptionForDuoChat(error);

      expect(Sentry.captureException).toHaveBeenCalledWith(error, expect.objectContaining({}));
    });

    it('always sets the feature_category tag to duo_chat', () => {
      captureExceptionForDuoChat(error);

      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: { feature_category: 'duo_chat' },
      });
    });

    it('merges caller-supplied options with the default tag', () => {
      captureExceptionForDuoChat(error, { extra: { messageId: 'msg-1' } });

      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        extra: { messageId: 'msg-1' },
        tags: { feature_category: 'duo_chat' },
      });
    });

    it('lets caller-supplied tags extend the default tag', () => {
      captureExceptionForDuoChat(error, { tags: { tool_name: 'create_commit' } });

      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: { feature_category: 'duo_chat', tool_name: 'create_commit' },
      });
    });

    it('does not allow callers to override the feature_category tag', () => {
      captureExceptionForDuoChat(error, { tags: { feature_category: 'other_feature' } });

      expect(Sentry.captureException).toHaveBeenCalledWith(error, {
        tags: { feature_category: 'duo_chat' },
      });
    });
  });
});
