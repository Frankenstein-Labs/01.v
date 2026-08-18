import {
  DwsMockWebSocket,
  exposeMockSocket,
} from 'ee/ai/duo_agentic_chat/websocket/dws_mock_websocket';

describe('DwsMockWebSocket', () => {
  const TEST_URL = 'ws://localhost/api/v4/ai/duo_workflows/ws';

  let realSocket;
  let OriginalWebSocket;
  let subject;
  let handlers;

  beforeEach(() => {
    realSocket = {
      readyState: 0,
      send: jest.fn(),
      close: jest.fn(),
      onopen: null,
      onmessage: null,
      onclose: null,
      onerror: null,
    };

    OriginalWebSocket = global.WebSocket;
    global.WebSocket = jest.fn(() => realSocket);

    subject = new DwsMockWebSocket(TEST_URL);

    handlers = {
      onopen: jest.fn(),
      onmessage: jest.fn(),
      onclose: jest.fn(),
      onerror: jest.fn(),
    };
    Object.assign(subject, handlers);
  });

  afterEach(() => {
    global.WebSocket = OriginalWebSocket;
  });

  it('wraps a real WebSocket for the given URL', () => {
    expect(global.WebSocket).toHaveBeenCalledWith(TEST_URL);
  });

  describe('transparency', () => {
    it('proxies readyState', () => {
      realSocket.readyState = 1;

      expect(subject.readyState).toBe(1);
    });

    it('delegates send', () => {
      subject.send('payload');

      expect(realSocket.send).toHaveBeenCalledWith('payload');
    });

    it('delegates close', () => {
      subject.close(1000, 'bye');

      expect(realSocket.close).toHaveBeenCalledWith(1000, 'bye');
    });

    it.each(['onopen', 'onmessage', 'onclose', 'onerror'])(
      'forwards a real %s event to the assigned handler',
      (handler) => {
        const event = { some: 'event' };

        realSocket[handler](event);

        expect(handlers[handler]).toHaveBeenCalledWith(event);
      },
    );
  });

  describe('dispatchMockEvent', () => {
    it('synthesises open', () => {
      subject.dispatchMockEvent('open');

      expect(handlers.onopen).toHaveBeenCalledTimes(1);
    });

    it('synthesises message with the given data', () => {
      subject.dispatchMockEvent('message', { data: '{"newCheckpoint":{}}' });

      expect(handlers.onmessage).toHaveBeenCalledWith({ data: '{"newCheckpoint":{}}' });
    });

    // Without data the handler would fire with `{ data: undefined }`, which looks like a
    // delivered frame but decodes to nothing. Failing loudly is easier to diagnose.
    it.each([undefined, {}, { data: '' }])(
      'throws rather than emitting an empty message for payload %p',
      (payload) => {
        expect(() => subject.dispatchMockEvent('message', payload)).toThrow(
          'You should provide a message payload',
        );
        expect(handlers.onmessage).not.toHaveBeenCalled();
      },
    );

    it('synthesises error', () => {
      subject.dispatchMockEvent('error');

      expect(handlers.onerror).toHaveBeenCalledTimes(1);
    });

    it('ignores an unknown event', () => {
      subject.dispatchMockEvent('nonsense');

      expect(handlers.onopen).not.toHaveBeenCalled();
      expect(handlers.onmessage).not.toHaveBeenCalled();
      expect(handlers.onclose).not.toHaveBeenCalled();
      expect(handlers.onerror).not.toHaveBeenCalled();
    });

    describe('close', () => {
      it('synthesises close with the given code and reason', () => {
        subject.dispatchMockEvent('close', { code: 1013, reason: 'try later' });

        expect(handlers.onclose).toHaveBeenCalledWith({ code: 1013, reason: 'try later' });
      });

      it('defaults to an abnormal closure', () => {
        subject.dispatchMockEvent('close');

        expect(handlers.onclose).toHaveBeenCalledWith({ code: 1006, reason: '' });
      });

      it('closes the wrapped socket so the client does not reconnect over a live one', () => {
        subject.dispatchMockEvent('close', { code: 1001 });

        expect(realSocket.close).toHaveBeenCalled();
      });

      it('does not fire a second close when the wrapped socket closes afterwards', () => {
        subject.dispatchMockEvent('close', { code: 1001 });

        // The real socket reports its own close once we asked it to shut down.
        expect(realSocket.onclose).toBeNull();
        expect(handlers.onclose).toHaveBeenCalledTimes(1);
      });
    });
  });
});

describe('exposeMockSocket', () => {
  let worker;

  beforeEach(() => {
    worker = { postMessage: jest.fn() };
    exposeMockSocket(() => worker);
  });

  afterEach(() => {
    delete window.gl.dwsMockSocket;
  });

  it('exposes the helpers on gl.dwsMockSocket', () => {
    expect(window.gl.dwsMockSocket).toEqual({
      close: expect.any(Function),
      error: expect.any(Function),
      message: expect.any(Function),
      open: expect.any(Function),
    });
  });

  it.each`
    description                 | call                                                      | expected
    ${'close with a code'}      | ${() => window.gl.dwsMockSocket.close(1013, 'try later')} | ${{ type: 'mockEvent', event: 'close', payload: { code: 1013, reason: 'try later' } }}
    ${'close with defaults'}    | ${() => window.gl.dwsMockSocket.close()}                  | ${{ type: 'mockEvent', event: 'close', payload: { code: 1006, reason: '' } }}
    ${'error'}                  | ${() => window.gl.dwsMockSocket.error()}                  | ${{ type: 'mockEvent', event: 'error', payload: undefined }}
    ${'open'}                   | ${() => window.gl.dwsMockSocket.open()}                   | ${{ type: 'mockEvent', event: 'open', payload: undefined }}
    ${'message with a payload'} | ${() => window.gl.dwsMockSocket.message('{"a":1}')}       | ${{ type: 'mockEvent', event: 'message', payload: { data: '{"a":1}' } }}
  `('posts a mockEvent to the worker for $description', ({ call, expected }) => {
    call();

    expect(worker.postMessage).toHaveBeenCalledWith(expected);
  });

  // The getter is resolved per call so the helpers follow the caller's worker
  // rather than capturing whichever one existed at expose time.
  it('posts to the current worker rather than the one present at expose time', () => {
    const replacement = { postMessage: jest.fn() };
    worker = replacement;

    window.gl.dwsMockSocket.close(1001);

    expect(replacement.postMessage).toHaveBeenCalledWith({
      type: 'mockEvent',
      event: 'close',
      payload: { code: 1001, reason: '' },
    });
  });

  it('does nothing once the worker is gone', () => {
    worker = null;

    expect(() => window.gl.dwsMockSocket.close(1001)).not.toThrow();
  });
});
