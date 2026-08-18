import { InternalEvents } from '~/tracking';
import {
  TRIGGER_SOURCE_WEB_CHAT,
  TRACKING_EVENT_RECOMMEND_TOOL,
  TRACKING_EVENT_TOOL_SUCCEEDED,
  TRACKING_EVENT_TOOL_FAILED,
  TRACKING_EVENT_APPROVE_TOOL,
  TRACKING_EVENT_DENY_TOOL,
  TRACKING_EVENT_CLICK_THROUGH_FLOW_WIDGET,
  TRACKING_EVENT_CLICK_THROUGH_SESSION_PILL,
} from '../constants';

const trackedMessageIds = new Set();

let context = {
  sessionId: undefined,
  flowType: undefined,
  triggerSource: TRIGGER_SOURCE_WEB_CHAT,
  model: undefined,
};

const buildProperties = (toolName) => ({
  tool_name: toolName,
  session_id: context.sessionId,
  flow_type: context.flowType,
  trigger_source: context.triggerSource,
  model: context.model,
});

const trackDedupedEvent = (eventName, { messageId, toolName } = {}) => {
  if (!messageId || trackedMessageIds.has(messageId)) return;
  trackedMessageIds.add(messageId);
  InternalEvents.trackEvent(eventName, buildProperties(toolName));
};

export const EventsTracker = {
  reset() {
    trackedMessageIds.clear();
    context = {
      sessionId: undefined,
      flowType: undefined,
      triggerSource: TRIGGER_SOURCE_WEB_CHAT,
      model: undefined,
    };
  },

  updateContext({ sessionId, flowType, triggerSource, model } = {}) {
    if (sessionId !== undefined) context.sessionId = sessionId;
    if (flowType !== undefined) context.flowType = flowType;
    if (triggerSource !== undefined) context.triggerSource = triggerSource;
    if (model !== undefined) context.model = model;
  },

  trackToolRecommended({ messageId, toolName } = {}) {
    trackDedupedEvent(TRACKING_EVENT_RECOMMEND_TOOL, { messageId, toolName });
  },

  trackToolSucceeded({ messageId, toolName } = {}) {
    trackDedupedEvent(TRACKING_EVENT_TOOL_SUCCEEDED, { messageId, toolName });
  },

  trackToolFailed({ messageId, toolName } = {}) {
    trackDedupedEvent(TRACKING_EVENT_TOOL_FAILED, { messageId, toolName });
  },

  trackApproveTool({ toolName } = {}) {
    InternalEvents.trackEvent(TRACKING_EVENT_APPROVE_TOOL, buildProperties(toolName));
  },

  trackDenyTool({ toolName } = {}) {
    InternalEvents.trackEvent(TRACKING_EVENT_DENY_TOOL, buildProperties(toolName));
  },

  trackClickThroughFlowWidget({ toolName } = {}) {
    InternalEvents.trackEvent(TRACKING_EVENT_CLICK_THROUGH_FLOW_WIDGET, buildProperties(toolName));
  },

  trackClickThroughSessionPill({ workflowId } = {}) {
    InternalEvents.trackEvent(TRACKING_EVENT_CLICK_THROUGH_SESSION_PILL, {
      workflow_id: workflowId,
      session_id: context.sessionId,
      flow_type: context.flowType,
      trigger_source: context.triggerSource,
      model: context.model,
    });
  },
};
