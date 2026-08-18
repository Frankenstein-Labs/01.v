// WebSocket close codes
export const WS_CLOSE_NORMAL = 1000;
export const WS_CLOSE_GOING_AWAY = 1001; // server restart — retryable
export const WS_CLOSE_POLICY_VIOLATION = 1008;
export const WS_CLOSE_TRY_AGAIN_LATER = 1013;
export const WS_CLOSE_INVALID_REQUEST = 4400; // backend SendInvalidRequest() — non-retryable

export const MAX_WS_RETRIES = 3;
export const WS_RETRY_DELAY_MS = 1000;

// error codes
export const WORKFLOW_NOT_FOUND_CODE = 'WORKFLOW_NOT_FOUND';
export const NO_RESOURCE_PERMISSIONS = 'NO_RESOURCE_PERMISSIONS';
export const NO_DEFAULT_NAMESPACE_CODE = 'NO_DEFAULT_NAMESPACE';

export const FEEDBACK_TRACKING_EVENT = 'ai_duo_agentic_chat_feedback_submitted';
export const CHAT_TRACKING_EVENT = 'trigger_ai_catalog_item';

export const TRACKING_EVENT_VIEW_EMPTY_STATE = 'view_dap_trial_or_paid_empty_state';
export const TRACKING_EVENT_CLICK_AGENT = 'click_dap_trial_or_paid_empty_state_agent';
export const TRACKING_EVENT_CLICK_PROMPT = 'click_dap_trial_or_paid_empty_state_prompt';
export const TRACKING_EVENT_CLICK_EXPLORE_AGENTS =
  'click_dap_trial_or_paid_empty_state_explore_agents_link';
export const TRACKING_EVENT_SUBMIT_MESSAGE = 'submit_dap_trial_or_paid_empty_state_message';

export const SUGGESTED_AGENTS_LIMIT = 3;

// The default foundational chat agent used when no specific agent is selected.
export const DEFAULT_AGENT_ID = 'gid://gitlab/Ai::FoundationalChatAgent/chat';

export const TRACKING_EVENT_RECOMMEND_TOOL = 'recommend_tool_duo_chat';
export const TRACKING_EVENT_TOOL_SUCCEEDED = 'tool_succeeded_duo_chat';
export const TRACKING_EVENT_TOOL_FAILED = 'tool_failed_duo_chat';
export const TRACKING_EVENT_APPROVE_TOOL = 'approve_tool_duo_chat';
export const TRACKING_EVENT_DENY_TOOL = 'deny_tool_duo_chat';
export const TRACKING_EVENT_CLICK_THROUGH_FLOW_WIDGET = 'click_through_flow_widget';
export const TRACKING_EVENT_CLICK_THROUGH_SESSION_PILL = 'click_through_session_pill';

export const TRIGGER_SOURCE_WEB_CHAT = 'web_chat';
export const TRIGGER_SOURCE_WEB_UI = 'web_ui';

export const TOOL_NAME_CLARIFICATION_QUESTION = 'clarification_question';
export const MESSAGE_SUB_TYPE_CLARIFICATION_ANSWER = 'clarification_answer';
export const MESSAGE_SUB_TYPE_TIER_ACCESS_DENIED = 'tier_access_denied';
