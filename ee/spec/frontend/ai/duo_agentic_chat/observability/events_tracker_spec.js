import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { EventsTracker } from 'ee/ai/duo_agentic_chat/observability/events_tracker';
import {
  TRIGGER_SOURCE_WEB_CHAT,
  TRACKING_EVENT_RECOMMEND_TOOL,
  TRACKING_EVENT_TOOL_SUCCEEDED,
  TRACKING_EVENT_TOOL_FAILED,
  TRACKING_EVENT_APPROVE_TOOL,
  TRACKING_EVENT_DENY_TOOL,
  TRACKING_EVENT_CLICK_THROUGH_FLOW_WIDGET,
  TRACKING_EVENT_CLICK_THROUGH_SESSION_PILL,
} from 'ee/ai/duo_agentic_chat/constants';

describe('duo_agentic_chat/observability/events_tracker', () => {
  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const sessionId = '42';
  const flowType = 'my_agent';
  const model = 'claude-3-5-sonnet';
  const messageId = 'msg-1';
  const toolName = 'create_commit';

  let trackEventSpy;

  beforeEach(() => {
    EventsTracker.reset();
    ({ trackEventSpy } = bindInternalEventDocument());
  });

  const sharedProperties = () => ({
    session_id: sessionId,
    flow_type: flowType,
    trigger_source: TRIGGER_SOURCE_WEB_CHAT,
    model,
  });

  describe.each`
    method                    | trackingEvent
    ${'trackToolRecommended'} | ${TRACKING_EVENT_RECOMMEND_TOOL}
    ${'trackToolSucceeded'}   | ${TRACKING_EVENT_TOOL_SUCCEEDED}
    ${'trackToolFailed'}      | ${TRACKING_EVENT_TOOL_FAILED}
  `('$method', ({ method, trackingEvent }) => {
    beforeEach(() => EventsTracker.updateContext({ sessionId, flowType, model }));

    it('tracks with tool name and context', () => {
      EventsTracker[method]({ messageId, toolName });

      expect(trackEventSpy).toHaveBeenCalledWith(trackingEvent, {
        tool_name: toolName,
        ...sharedProperties(),
      });
    });

    it('does not track the same messageId twice', () => {
      EventsTracker[method]({ messageId, toolName });
      EventsTracker[method]({ messageId, toolName });

      expect(trackEventSpy).toHaveBeenCalledTimes(1);
    });

    it('does not track when messageId is missing', () => {
      EventsTracker.trackToolRecommended({ toolName });

      expect(trackEventSpy).not.toHaveBeenCalled();
    });
  });

  describe.each`
    method                           | trackingEvent
    ${'trackApproveTool'}            | ${TRACKING_EVENT_APPROVE_TOOL}
    ${'trackDenyTool'}               | ${TRACKING_EVENT_DENY_TOOL}
    ${'trackClickThroughFlowWidget'} | ${TRACKING_EVENT_CLICK_THROUGH_FLOW_WIDGET}
  `('$method', ({ method, trackingEvent }) => {
    it('tracks with tool name and context', () => {
      EventsTracker.updateContext({ sessionId, flowType, model });
      EventsTracker[method]({ toolName });

      expect(trackEventSpy).toHaveBeenCalledWith(trackingEvent, {
        tool_name: toolName,
        ...sharedProperties(),
      });
    });
  });

  describe('trackClickThroughSessionPill', () => {
    it('tracks with workflow id and context', () => {
      EventsTracker.updateContext({ sessionId, flowType, model });
      EventsTracker.trackClickThroughSessionPill({ workflowId: 326 });

      expect(trackEventSpy).toHaveBeenCalledWith(TRACKING_EVENT_CLICK_THROUGH_SESSION_PILL, {
        workflow_id: 326,
        ...sharedProperties(),
      });
    });
  });
});
