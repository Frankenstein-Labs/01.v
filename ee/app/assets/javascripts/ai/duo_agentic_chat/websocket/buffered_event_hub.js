import createEventHub from '~/helpers/event_hub_factory';
import { captureExceptionForDuoChat } from '../observability/sentry_utils';
import { BufferOverflowError } from './buffer_overflow_error';

const MAX_BUFFER_SIZE = 1000;

/**
 * Event hub that replays past events to late subscribers.
 *
 * Subscribers of a buffered event type receive everything already emitted for
 * that type before they subscribed, and then live events as usual. Without
 * that, a reconnect or a component mounting mid-stream silently drops every
 * event delivered in the gap.
 *
 * Buffering is a property of the event type, declared once in the constructor,
 * so emitting is all a producer has to do. Each buffered type gets its own
 * bounded buffer; types not listed pass straight through.
 */
export class BufferedEventHub {
  #eventHub = createEventHub();
  // Doubles as the set of buffered types: a type is buffered iff it has an entry.
  #buffers = new Map();

  constructor(bufferedEvents = []) {
    // A bare string is iterable, so passing one would quietly create a buffer
    // per character instead of failing.
    if (!Array.isArray(bufferedEvents)) {
      throw new TypeError('bufferedEvents must be an array of event names');
    }

    for (const eventType of bufferedEvents) {
      this.#buffers.set(eventType, []);
    }
  }

  $emit(type, payload) {
    const buffer = this.#buffers.get(type);
    if (buffer) {
      if (buffer.length >= MAX_BUFFER_SIZE) {
        throw new BufferOverflowError(type, MAX_BUFFER_SIZE);
      }
      buffer.push(payload);
    }

    this.#eventHub.$emit(type, payload);
  }

  subscribe(eventType, callback) {
    const safeCallback = (payload) => {
      try {
        callback(payload);
      } catch (e) {
        captureExceptionForDuoChat(e);
      }
    };

    this.#eventHub.$on(eventType, safeCallback);

    for (const payload of this.#buffers.get(eventType) ?? []) {
      safeCallback(payload);
    }

    return { dispose: () => this.#eventHub.$off(eventType, safeCallback) };
  }

  clear() {
    // Emptied in place so the keys survive: a type stays buffered after a clear.
    for (const buffer of this.#buffers.values()) {
      buffer.length = 0;
    }
  }

  dispose() {
    this.clear();
    this.#eventHub.dispose();
  }

  get count() {
    let total = 0;
    for (const buffer of this.#buffers.values()) {
      total += buffer.length;
    }
    return total;
  }
}
