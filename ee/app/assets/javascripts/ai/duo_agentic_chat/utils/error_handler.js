import { s__ } from '~/locale';
import { NO_RESOURCE_PERMISSIONS } from '../constants';

/**
 * Error handler definition:
 * - match(err): Returns true if this handler should process the error
 * - format(err): Returns the formatted error message string
 */
const errorHandlers = [
  {
    match: (err) =>
      err?.graphQLErrors?.some((e) => e?.extensions?.code === NO_RESOURCE_PERMISSIONS),
    format: () =>
      s__(
        "DuoAgenticChat|I don't have access to that resource at the moment. Is there something else I can help you with?",
      ),
  },
];

/**
 * Formats an error message using registered handlers.
 * Returns formatted message from first matching handler, or default format.
 *
 * @param {Error} err - The error to format
 * @returns {string} - The formatted error message
 */
export const formatErrorMessage = (err) => {
  const matchingHandlers = errorHandlers.filter((h) => h.match(err));

  if (matchingHandlers.length === 0) {
    return err.toString();
  }

  return matchingHandlers.map((h) => h.format(err)).join('\n');
};
