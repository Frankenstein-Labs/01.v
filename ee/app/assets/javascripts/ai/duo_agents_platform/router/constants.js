export const AGENTS_PLATFORM_INDEX_ROUTE = 'agents_platform_index_route';
export const AGENTS_PLATFORM_SHOW_ROUTE = 'agents_platform_show_route';

export const AGENTIC_CHAT_HISTORY_ROUTE = 'agentic_chat_history_route';
export const AGENTIC_CHAT_NEW_ROUTE = 'agentic_chat_new_route';
export const AGENTIC_CHAT_SHOW_ROUTE = 'agentic_chat_show_route';
export const AGENTIC_CHAT_BLOCKED_ROUTE = 'agentic_chat_blocked_route';

export const CLASSIC_CHAT_HISTORY_ROUTE = 'classic_chat_history_route';
export const CLASSIC_CHAT_NEW_ROUTE = 'classic_chat_new_route';
export const CLASSIC_CHAT_SHOW_ROUTE = 'classic_chat_show_route';

export const CLOSED_ROUTE = 'closed_route';

// Maps route names to tab names for syncing activeTab from route
export const ROUTE_TO_TAB = {
  [AGENTIC_CHAT_SHOW_ROUTE]: 'chat',
  [AGENTIC_CHAT_NEW_ROUTE]: 'chat',
  [AGENTIC_CHAT_HISTORY_ROUTE]: 'history',
  [AGENTIC_CHAT_BLOCKED_ROUTE]: 'chat',
  [CLASSIC_CHAT_SHOW_ROUTE]: 'chat',
  [CLASSIC_CHAT_NEW_ROUTE]: 'chat',
  [CLASSIC_CHAT_HISTORY_ROUTE]: 'history',
  [AGENTS_PLATFORM_INDEX_ROUTE]: 'sessions',
  [AGENTS_PLATFORM_SHOW_ROUTE]: 'sessions',
};

// Map workflow end messages to the new page
export const WORKFLOW_END_PAGE_LINK = 'workflow-new';

// Triggers routes
export const FLOW_TRIGGERS_INDEX_ROUTE = 'flow_triggers_index_route';
export const FLOW_TRIGGERS_NEW_ROUTE = 'flow_triggers_new_route';
export const FLOW_TRIGGERS_EDIT_ROUTE = 'flow_triggers_edit_route';

// MCP servers routes
export const MCP_SERVERS_INDEX_ROUTE = 'mcp_servers_index_route';
export const MCP_SERVERS_SHOW_ROUTE = 'mcp_servers_show_route';

// Onboarding routes
export const AGENTS_PLATFORM_ONBOARDING_ROUTE = 'onboarding_index';
