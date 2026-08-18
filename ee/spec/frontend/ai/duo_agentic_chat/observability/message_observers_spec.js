import { initMessageObservers } from 'ee/ai/duo_agentic_chat/observability/message_observers';
import {
  DUO_CHAT_TOOL_REQUESTED_EVENT,
  DUO_CHAT_TOOL_COMPLETED_EVENT,
  DUO_CHAT_TOOL_FAILURE_EVENT,
  subscribeToEvent,
} from 'ee/ai/duo_agentic_chat/events/event_hub';
import * as sentryUtils from 'ee/ai/duo_agentic_chat/observability/sentry_utils';
import { MOCK_CHAT_MESSAGES } from '../utils/mock_data';

jest.mock('ee/ai/duo_agentic_chat/events/event_hub', () => ({
  ...jest.requireActual('ee/ai/duo_agentic_chat/events/event_hub'),
  subscribeToEvent: jest.fn(),
}));

jest.mock('ee/ai/duo_agentic_chat/observability/sentry_utils');

describe('initMessageObservers', () => {
  let registeredHandlers;
  let mockEventsTracker;
  let disposable;

  beforeEach(() => {
    registeredHandlers = {};
    subscribeToEvent.mockImplementation((event, handler) => {
      registeredHandlers[event] = handler;
      return { dispose: jest.fn() };
    });

    mockEventsTracker = {
      trackToolRecommended: jest.fn(),
      trackToolSucceeded: jest.fn(),
      trackToolFailed: jest.fn(),
    };

    disposable = initMessageObservers(mockEventsTracker);
  });

  it.each`
    event                            | payload                                          | trackerMethod
    ${DUO_CHAT_TOOL_REQUESTED_EVENT} | ${{ messageId: 'msg-1', name: 'create_commit' }} | ${'trackToolRecommended'}
    ${DUO_CHAT_TOOL_COMPLETED_EVENT} | ${{ messageId: 'msg-2', name: 'update_form' }}   | ${'trackToolSucceeded'}
    ${DUO_CHAT_TOOL_FAILURE_EVENT}   | ${{ messageId: 'msg-3', name: 'run_command' }}   | ${'trackToolFailed'}
  `(
    'calls eventsTracker.$trackerMethod when $event is emitted',
    ({ event, payload, trackerMethod }) => {
      registeredHandlers[event](payload);

      expect(mockEventsTracker[trackerMethod]).toHaveBeenCalledWith({
        messageId: payload.messageId,
        toolName: payload.name,
      });
    },
  );

  describe('tool failure Sentry reporting', () => {
    it('captures the failure content as an exception with the tool name tag', () => {
      const [failedTool] = MOCK_CHAT_MESSAGES.tool3Fail;
      const payload = {
        messageId: failedTool.message_id,
        name: failedTool.tool_info.name,
        content: failedTool.content,
      };

      registeredHandlers[DUO_CHAT_TOOL_FAILURE_EVENT](payload);

      expect(sentryUtils.captureExceptionForDuoChat).toHaveBeenCalledWith(
        new Error(`${failedTool.tool_info.name}: ${failedTool.content}`),
      );
    });
  });

  describe('dispose', () => {
    it('disposes all event subscriptions', () => {
      const subscriptionDisposables = subscribeToEvent.mock.results.map((r) => r.value.dispose);

      disposable.dispose();

      subscriptionDisposables.forEach((dispose) => {
        expect(dispose).toHaveBeenCalled();
      });
    });
  });
});
