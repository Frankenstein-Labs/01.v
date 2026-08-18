/**
 * Thrown by BufferedEventHub when a buffered event type has no room left.
 *
 * Overflow means the producer has outrun the buffer's purpose, so it is
 * reported rather than swallowed: dropping the event silently would leave late
 * subscribers replaying a truncated history with no trace of the gap.
 *
 * `eventType` is carried as a field so the offending buffer is identifiable
 * from a Sentry report without parsing the message.
 */
export class BufferOverflowError extends Error {
  constructor(eventType, limit) {
    super(`Buffer for "${eventType}" reached its limit of ${limit} events`);
    this.name = 'BufferOverflowError';
    this.eventType = eventType;
  }
}
