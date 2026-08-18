import { captureExceptionForDuoChat } from './sentry_utils';

const LOG_PREFIX = '[duo-chat][stream]';

/**
 * Logs every close, whatever the code.
 *
 * A stream that ends deserves a line even when ending was the correct outcome:
 * the symptom users report is always "it just stopped", and which close code
 * produced that is the first thing worth knowing. Kept at `info` so it is a
 * breadcrumb rather than a fault -- `console.error` here would also fail every
 * jest suite that closes a stream, since ConsoleWatcher turns those into throws.
 */
export const logStreamClose = ({ code, reason, category, retryable }) => {
  // eslint-disable-next-line no-console
  console.info(`${LOG_PREFIX} closed`, {
    code,
    category,
    retryable,
    reason: reason || null,
  });
};

/** Why a reconnect is happening: on its own after a close, or because it was asked for. */
export const RECONNECT_TRIGGERS = {
  RETRYABLE_CLOSE: 'retryable_close',
  REQUESTED: 'requested',
};

/**
 * Logged, never reported: a reconnect that works is not an incident. Without
 * this line the console shows a close followed by silence, which reads like the
 * stream gave up, and then an open that came from nowhere.
 *
 * `consecutiveFailures` is the count before this attempt, so a requested
 * reconnect still says how many automatic ones preceded it.
 */
export const logStreamReconnect = ({ trigger, consecutiveFailures, maxRetries, delay }) => {
  // eslint-disable-next-line no-console
  console.info(`${LOG_PREFIX} reconnecting`, { trigger, consecutiveFailures, maxRetries, delay });
};

/**
 * Sends to Sentry only the closes a human should look at.
 *
 * Most close codes are outcomes rather than faults: a normal shutdown, a server
 * restart, another tab already holding the workflow, a user out of credits.
 * Reporting those would bury the ones that mean something. What is left is a
 * request the backend rejected, a code we do not recognise, and -- whatever the
 * code -- a close that could not be recovered from, because it is the recovery
 * that made a transient close ignorable in the first place.
 *
 * @param {Object} event The categorised close event.
 * @param {boolean} options.retriesExhausted Reconnection has been given up on,
 *   which makes even an otherwise expected close worth reporting.
 */
export const reportStreamClose = (
  { code, reason, category, expected },
  { retriesExhausted = false } = {},
) => {
  if (expected && !retriesExhausted) return;

  // Sentry titles, read by us and never by a user, so deliberately not translated.
  /* eslint-disable @gitlab/require-i18n-strings */
  const summary = retriesExhausted
    ? `Duo Chat stream could not be recovered after close ${code} (${category})`
    : `Duo Chat stream closed with ${code} (${category})`;
  /* eslint-enable @gitlab/require-i18n-strings */

  captureExceptionForDuoChat(new Error(summary), {
    tags: { duo_chat_stream_close: category },
    extra: { code, reason: reason || null, retriesExhausted },
  });
};
