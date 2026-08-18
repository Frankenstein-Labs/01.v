import { CLIENT_TYPES, DEFAULT_CLIENT_TYPE } from './constants';

/**
 * Converts a snake_case audit event name into a human-readable title.
 *
 * Examples:
 *   'ai_agent_session_ended'   => 'Agent session ended'
 *   'ai_llm_input_sent'        => 'Llm input sent'
 *   'ai_tool_invoked'          => 'Tool invoked'
 *
 * @param {string} name - The raw event name from the API.
 * @returns {string}
 */
export function formatEventName(name) {
  if (!name) return '';
  return name
    .replace(/^ai_/, '')
    .replace(/_/g, ' ')
    .replace(/^./, (c) => c.toUpperCase());
}

/**
 * Returns the client type object for a session artifact item.
 *
 * The backend does not currently expose a `clientType` value on session
 * artifacts — GitLab Duo is the only client type shown today. This mapping
 * will become functional in a future iteration once the backend includes
 * client type data.
 *
 * @param {Object} item - A session artifact item.
 * @returns {{ name: string, icon: string }}
 */
export function getClientType(item) {
  return (item.clientType && CLIENT_TYPES[item.clientType]) || DEFAULT_CLIENT_TYPE;
}
