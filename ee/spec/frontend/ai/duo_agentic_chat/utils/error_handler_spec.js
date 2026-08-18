import { formatErrorMessage } from 'ee/ai/duo_agentic_chat/utils/error_handler';
import { NO_RESOURCE_PERMISSIONS } from 'ee/ai/duo_agentic_chat/constants';

describe('error_handler', () => {
  describe('formatErrorMessage', () => {
    describe('when error has NO_RESOURCE_PERMISSIONS GraphQL error', () => {
      it('returns the custom access denied message', () => {
        const error = {
          graphQLErrors: [
            {
              extensions: {
                code: NO_RESOURCE_PERMISSIONS,
              },
            },
          ],
          toString: () => 'GraphQL error: No resource permissions',
        };

        const result = formatErrorMessage(error);

        expect(result).toBe(
          "I don't have access to that resource at the moment. Is there something else I can help you with?",
        );
      });

      it('matches when NO_RESOURCE_PERMISSIONS is among multiple GraphQL errors', () => {
        const error = {
          graphQLErrors: [
            { extensions: { code: 'SOME_OTHER_ERROR' } },
            { extensions: { code: NO_RESOURCE_PERMISSIONS } },
          ],
          toString: () => 'Multiple errors',
        };

        const result = formatErrorMessage(error);

        expect(result).toBe(
          "I don't have access to that resource at the moment. Is there something else I can help you with?",
        );
      });
    });

    describe('when error matches multiple handlers', () => {
      it('returns all matching handler messages combined', () => {
        const error = {
          graphQLErrors: [
            { extensions: { code: NO_RESOURCE_PERMISSIONS } },
            { extensions: { code: 'ANOTHER_HANDLED_CODE' } },
          ],
          toString: () => 'Multiple errors',
        };

        const result = formatErrorMessage(error);

        expect(result).toContain("I don't have access to that resource at the moment.");
      });
    });

    describe('when error does not match any handler', () => {
      it('returns the default error string', () => {
        const error = {
          graphQLErrors: [{ extensions: { code: 'UNKNOWN_ERROR' } }],
          toString: () => 'Error: Something went wrong',
        };

        const result = formatErrorMessage(error);

        expect(result).toBe('Error: Something went wrong');
      });

      it('handles errors with missing extensions', () => {
        const error = {
          graphQLErrors: [{ message: 'No extensions' }],
          toString: () => 'No extensions error',
        };

        const result = formatErrorMessage(error);

        expect(result).toBe('No extensions error');
      });
    });
  });
});
