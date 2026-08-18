import { BufferedEventHub } from 'ee/ai/duo_agentic_chat/websocket/buffered_event_hub';
import { BufferOverflowError } from 'ee/ai/duo_agentic_chat/websocket/buffer_overflow_error';
import { captureExceptionForDuoChat } from 'ee/ai/duo_agentic_chat/observability/sentry_utils';

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils');

describe('BufferedEventHub', () => {
  const MAX_BUFFER_SIZE = 1000;

  let hub;

  // Fills a type's buffer exactly to capacity, so the next emit overflows.
  function fillBuffer(target, eventType) {
    for (let i = 0; i < MAX_BUFFER_SIZE; i += 1) {
      target.$emit(eventType, { i });
    }
  }

  beforeEach(() => {
    hub = new BufferedEventHub(['message']);
  });

  describe('constructor', () => {
    it('buffers nothing when no event types are given', () => {
      const plainHub = new BufferedEventHub();
      plainHub.$emit('message', { type: 'message' });

      expect(plainHub.count).toBe(0);
    });

    // A string is iterable, so without this guard 'message' would quietly
    // register a buffer per character.
    it.each(['message', 42, {}])('rejects a non-array argument: %p', (arg) => {
      expect(() => new BufferedEventHub(arg)).toThrow(TypeError);
    });
  });

  describe('pub/sub', () => {
    it('delivers emitted events to subscribers', () => {
      const callback = jest.fn();
      hub.subscribe('open', callback);

      hub.$emit('open', { type: 'open' });

      expect(callback).toHaveBeenCalledWith({ type: 'open' });
    });

    it('stops delivering events after the subscription is disposed', () => {
      const callback = jest.fn();
      const sub = hub.subscribe('open', callback);

      sub.dispose();
      hub.$emit('open', { type: 'open' });

      expect(callback).not.toHaveBeenCalled();
    });
  });

  describe('buffering', () => {
    it('starts empty', () => {
      expect(hub.count).toBe(0);
    });

    it('buffers events emitted for a buffered type', () => {
      hub.$emit('message', { type: 'message' });

      expect(hub.count).toBe(1);
    });

    it('does not buffer events for a type outside the constructor list', () => {
      hub.$emit('open', { type: 'open' });

      expect(hub.count).toBe(0);
    });

    it('accepts events up to MAX_BUFFER_SIZE (1000)', () => {
      fillBuffer(hub, 'message');

      expect(hub.count).toBe(1000);
    });

    describe('once a buffer is full', () => {
      beforeEach(() => {
        fillBuffer(hub, 'message');
      });

      it('throws a BufferOverflowError naming the event type', () => {
        expect(() => hub.$emit('message', { overflow: true })).toThrow(BufferOverflowError);
      });

      // Dropping the event silently would leave late subscribers replaying a
      // truncated history with no trace of the gap.
      it('does not buffer the overflowing event', () => {
        expect(() => hub.$emit('message', { overflow: true })).toThrow();

        expect(hub.count).toBe(1000);
      });

      // The throw happens before dispatch, so nothing is delivered either. This
      // is the surprising half of the contract, so it is pinned explicitly.
      it('does not deliver the overflowing event to subscribers', () => {
        const callback = jest.fn();
        hub.subscribe('message', callback);
        callback.mockClear();

        expect(() => hub.$emit('message', { overflow: true })).toThrow();

        expect(callback).not.toHaveBeenCalled();
      });

      it('accepts events again after clear()', () => {
        hub.clear();

        hub.$emit('message', { afterClear: true });

        expect(hub.count).toBe(1);
      });

      it('leaves other event types unaffected', () => {
        const multiHub = new BufferedEventHub(['message', 'open']);
        fillBuffer(multiHub, 'message');

        multiHub.$emit('open', { o: 1 });

        expect(multiHub.count).toBe(1001);
      });
    });
  });

  describe('clear', () => {
    it('resets count to zero', () => {
      hub.$emit('message', { type: 'message' });
      hub.$emit('message', { type: 'message' });

      hub.clear();

      expect(hub.count).toBe(0);
    });

    it('keeps buffering after a clear', () => {
      hub.$emit('message', { type: 'message' });
      hub.clear();

      hub.$emit('message', { type: 'message' });

      expect(hub.count).toBe(1);
    });
  });

  describe('dispose', () => {
    it('clears the buffer', () => {
      hub.$emit('message', { type: 'message' });
      hub.$emit('message', { type: 'message' });

      hub.dispose();

      expect(hub.count).toBe(0);
    });
  });

  describe('replay', () => {
    it('replays buffered events to a new subscriber', () => {
      const first = { type: 'message', data: { id: 1 } };
      const second = { type: 'message', data: { id: 2 } };
      hub.$emit('message', first);
      hub.$emit('message', second);

      const callback = jest.fn();
      hub.subscribe('message', callback);

      expect(callback).toHaveBeenCalledTimes(2);
      expect(callback).toHaveBeenNthCalledWith(1, first);
      expect(callback).toHaveBeenNthCalledWith(2, second);
    });

    it('does not replay to subscribers of another event type', () => {
      hub.$emit('message', { type: 'message' });

      const callback = jest.fn();
      hub.subscribe('open', callback);

      expect(callback).not.toHaveBeenCalled();
    });

    it('replays past events and then delivers future ones', () => {
      const past = { past: true };
      hub.$emit('message', past);

      const callback = jest.fn();
      hub.subscribe('message', callback);

      const future = { future: true };
      hub.$emit('message', future);

      expect(callback).toHaveBeenCalledTimes(2);
      expect(callback).toHaveBeenNthCalledWith(1, past);
      expect(callback).toHaveBeenNthCalledWith(2, future);
    });

    it('does not drain the buffer, so every new subscriber sees it', () => {
      hub.$emit('message', { type: 'message' });

      const first = jest.fn();
      const second = jest.fn();
      hub.subscribe('message', first);
      hub.subscribe('message', second);

      expect(first).toHaveBeenCalledTimes(1);
      expect(second).toHaveBeenCalledTimes(1);
      expect(hub.count).toBe(1);
    });

    it('uses the event types given to the constructor, not a hardcoded one', () => {
      const customHub = new BufferedEventHub(['data']);
      const item = { value: 42 };
      customHub.$emit('data', item);

      const messageCallback = jest.fn();
      customHub.subscribe('message', messageCallback);

      expect(messageCallback).not.toHaveBeenCalled();

      const dataCallback = jest.fn();
      customHub.subscribe('data', dataCallback);

      expect(dataCallback).toHaveBeenCalledWith(item);
    });

    describe('with several buffered event types', () => {
      let multiHub;

      beforeEach(() => {
        multiHub = new BufferedEventHub(['message', 'open']);
        multiHub.$emit('message', { m: 1 });
        multiHub.$emit('open', { o: 1 });
        multiHub.$emit('message', { m: 2 });
      });

      it('sums count across every buffer', () => {
        expect(multiHub.count).toBe(3);
      });

      it('replays each type independently', () => {
        const messageCallback = jest.fn();
        const openCallback = jest.fn();

        multiHub.subscribe('message', messageCallback);
        multiHub.subscribe('open', openCallback);

        expect(messageCallback).toHaveBeenCalledTimes(2);
        expect(messageCallback).toHaveBeenNthCalledWith(1, { m: 1 });
        expect(messageCallback).toHaveBeenNthCalledWith(2, { m: 2 });
        expect(openCallback).toHaveBeenCalledTimes(1);
        expect(openCallback).toHaveBeenCalledWith({ o: 1 });
      });

      it('clears every buffer at once', () => {
        multiHub.clear();

        expect(multiHub.count).toBe(0);
      });
    });
  });

  describe('safe callback (Sentry wrapping)', () => {
    it('captures subscriber exceptions via captureExceptionForDuoChat', () => {
      const error = new Error('subscriber crashed');
      hub.subscribe(
        'open',
        jest.fn().mockImplementation(() => {
          throw error;
        }),
      );

      hub.$emit('open', { type: 'open' });

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });

    it('continues processing after a subscriber throws', () => {
      const safe = jest.fn();
      hub.subscribe(
        'open',
        jest.fn().mockImplementation(() => {
          throw new Error('boom');
        }),
      );
      hub.subscribe('open', safe);

      hub.$emit('open', { type: 'open' });

      expect(safe).toHaveBeenCalled();
    });

    it('wraps replay callbacks in the same safe handler', () => {
      const error = new Error('replay crash');
      hub.$emit('message', { type: 'message' });

      hub.subscribe(
        'message',
        jest.fn().mockImplementation(() => {
          throw error;
        }),
      );

      expect(captureExceptionForDuoChat).toHaveBeenCalledWith(error);
    });
  });
});
