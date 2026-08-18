import { WorkflowStreamFactory } from 'ee/ai/duo_agentic_chat/websocket/workflow_stream_factory';
import { RetryableWorkflowStream } from 'ee/ai/duo_agentic_chat/websocket/retryable_workflow_stream';
import StreamWorker from 'ee/ai/duo_agentic_chat/websocket/stream_worker';

const mockPostMessage = jest.fn();
const mockTerminate = jest.fn();
const mockAddEventListener = jest.fn();
const mockRemoveEventListener = jest.fn();

jest.mock('ee/ai/duo_agentic_chat/websocket/stream_worker', () =>
  jest.fn().mockImplementation(() => ({
    postMessage: mockPostMessage,
    terminate: mockTerminate,
    addEventListener: mockAddEventListener,
    removeEventListener: mockRemoveEventListener,
  })),
);

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils', () => ({
  captureExceptionForDuoChat: jest.fn(),
}));

describe('WorkflowStreamFactory', () => {
  const TEST_URL = 'ws://localhost/api/v4/ai/duo_workflows/ws';
  const TEST_INITIAL_MESSAGE = { startRequest: { workflowID: '123' } };

  let factory;

  beforeEach(() => {
    // Reconnect delays are jittered; pin the randomness so they are exact here.
    jest.spyOn(Math, 'random').mockReturnValue(1);
    mockPostMessage.mockClear();
    mockTerminate.mockClear();
    mockAddEventListener.mockClear();
    StreamWorker.mockClear();
    factory = new WorkflowStreamFactory();
  });

  describe('getWorkflowStream()', () => {
    it('returns a RetryableWorkflowStream', () => {
      expect(factory.getWorkflowStream()).toBeInstanceOf(RetryableWorkflowStream);
    });

    it('returns the same instance on every call', () => {
      expect(factory.getWorkflowStream()).toBe(factory.getWorkflowStream());
    });

    it('starts in idle state before connect() is called', () => {
      expect(factory.getWorkflowStream().getStatus().state).toBe('idle');
    });

    it('does not create a new WorkflowStream on repeated calls', () => {
      factory.getWorkflowStream().connect(TEST_URL, TEST_INITIAL_MESSAGE);
      const workerCount = StreamWorker.mock.instances.length;

      factory.getWorkflowStream();
      factory.getWorkflowStream();

      expect(StreamWorker.mock.instances).toHaveLength(workerCount);
    });
  });

  describe('constructor options', () => {
    it('passes maxRetries to the retryable stream', () => {
      jest.useFakeTimers();
      factory = new WorkflowStreamFactory({ maxRetries: 1 });
      factory.getWorkflowStream().connect(TEST_URL, TEST_INITIAL_MESSAGE);

      const [, handler] = mockAddEventListener.mock.calls.find(([e]) => e === 'message');

      const errorCallback = jest.fn();
      factory.getWorkflowStream().subscribe('error', errorCallback);

      handler({ data: { type: 'open' } });

      handler({ data: { type: 'close', code: 1001 } }); // count=1 → retry
      jest.runAllTimers();
      handler({ data: { type: 'close', code: 1001 } }); // count=2 > 1 → error

      expect(errorCallback).toHaveBeenCalledWith(
        expect.objectContaining({ reason: 'max_retries_exceeded' }),
      );
      jest.useRealTimers();
    });

    it('passes retryDelay to the retryable stream', () => {
      jest.useFakeTimers();
      factory = new WorkflowStreamFactory({ retryDelay: 500 });
      factory.getWorkflowStream().connect(TEST_URL, TEST_INITIAL_MESSAGE);

      const [, handler] = mockAddEventListener.mock.calls.find(([e]) => e === 'message');

      handler({ data: { type: 'open' } });
      handler({ data: { type: 'close', code: 1001 } });

      jest.advanceTimersByTime(499);
      expect(mockPostMessage).toHaveBeenCalledTimes(1);

      jest.advanceTimersByTime(1);
      expect(mockPostMessage).toHaveBeenCalledTimes(2);

      jest.useRealTimers();
    });
  });

  // The decorator's own spec covers this against a fake inner. Here the worker is
  // real enough to show the actual cost of getting it wrong: a second worker and
  // socket, created after the stream was torn down and owned by nobody.
  describe('tearing down mid-retry', () => {
    beforeEach(() => {
      jest.useFakeTimers();
      factory.getWorkflowStream().connect(TEST_URL, TEST_INITIAL_MESSAGE);

      const [, handler] = mockAddEventListener.mock.calls.find(([e]) => e === 'message');
      handler({ data: { type: 'open' } });
      handler({ data: { type: 'close', code: 1001 } });
      mockPostMessage.mockClear();
      StreamWorker.mockClear();
    });

    afterEach(() => {
      jest.useRealTimers();
    });

    it.each(['disconnect', 'terminate'])('does not reconnect after %s()', (method) => {
      factory.getWorkflowStream()[method]();

      jest.runAllTimers();

      expect(mockPostMessage).not.toHaveBeenCalledWith(
        expect.objectContaining({ type: 'connect' }),
      );
      expect(StreamWorker).not.toHaveBeenCalled();
    });
  });

  describe('module-level singleton', () => {
    it('exports a pre-constructed singleton', async () => {
      const { workflowStreamFactory } =
        await import('ee/ai/duo_agentic_chat/websocket/workflow_stream_factory');
      expect(workflowStreamFactory).toBeInstanceOf(WorkflowStreamFactory);
    });
  });
});
