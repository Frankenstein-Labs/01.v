import {
  AGENT_PLATFORM_PROJECT_PAGE,
  AGENT_PLATFORM_GROUP_PAGE,
  AGENT_PLATFORM_USER_PAGE,
} from '../constants';
import ProjectAgentsPlatformIndex from '../namespace/project/project_agents_platform_index.vue';
import userAgentsPlatformIndex from '../namespace/user/user_agents_platform_index.vue';
import ProjectMcpServersIndex from '../namespace/project/project_mcp_servers_index.vue';
import GroupMcpServersIndex from '../namespace/group/group_mcp_servers_index.vue';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
  AGENTIC_CHAT_NEW_ROUTE,
  AGENTIC_CHAT_SHOW_ROUTE,
  CLASSIC_CHAT_HISTORY_ROUTE,
  CLASSIC_CHAT_NEW_ROUTE,
  CLASSIC_CHAT_SHOW_ROUTE,
} from './constants';

export const getNamespaceIndexComponent = (namespace) => {
  if (!namespace) {
    throw new Error(`The namespace argument must be passed to the Vue Router`);
  }

  const componentMappings = {
    [AGENT_PLATFORM_PROJECT_PAGE]: ProjectAgentsPlatformIndex,
    [AGENT_PLATFORM_USER_PAGE]: userAgentsPlatformIndex,
  };

  return componentMappings[namespace];
};

export const getMcpServersIndexComponent = (namespace) => {
  if (!namespace) {
    throw new Error(`The namespace argument must be passed to the Vue Router`);
  }

  const componentMappings = {
    [AGENT_PLATFORM_PROJECT_PAGE]: ProjectMcpServersIndex,
    [AGENT_PLATFORM_GROUP_PAGE]: GroupMcpServersIndex,
  };

  return componentMappings[namespace];
};

let previousRoute = null;
export const getPreviousRoute = () => previousRoute;
export const setPreviousRoute = (route) => {
  previousRoute = route;
};

/**
 * Returns the default route name for a given tab and chat mode.
 * @param {string} tab - The tab name ('chat', 'sessions', 'suggestions')
 * @param {boolean} isAgenticMode - Whether agentic mode is enabled
 * @returns {string} The route name to navigate to
 */
export const getDefaultRouteForTab = (tab, isAgenticMode) => {
  switch (tab) {
    case 'chat':
      return isAgenticMode ? AGENTIC_CHAT_SHOW_ROUTE : CLASSIC_CHAT_SHOW_ROUTE;
    case 'new':
      return isAgenticMode ? AGENTIC_CHAT_NEW_ROUTE : CLASSIC_CHAT_NEW_ROUTE;
    case 'history':
      return isAgenticMode ? AGENTIC_CHAT_HISTORY_ROUTE : CLASSIC_CHAT_HISTORY_ROUTE;
    case 'sessions':
      return AGENTS_PLATFORM_INDEX_ROUTE;
    default:
      return isAgenticMode ? AGENTIC_CHAT_SHOW_ROUTE : CLASSIC_CHAT_SHOW_ROUTE;
  }
};
