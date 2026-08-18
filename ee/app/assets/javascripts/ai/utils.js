import { duoChatGlobalState } from '~/super_sidebar/state';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { setCookie, getCookie } from '~/lib/utils/common_utils';
import { getStorageValue, saveStorageValue } from '~/lib/utils/local_storage';
import {
  DUO_AGENTIC_MODE_COOKIE,
  DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  CHAT_MODES,
} from 'ee/ai/tanuki_bot/constants';
import { eventHub, SHOW_NEW_CHAT } from './events/panel';

/**
 * Derive a stable, non-negative integer from an agent id to use as a GlAvatar `entityId`.
 *
 * GlAvatar's identicon color comes from `entityId` (entityId % 7 + 1), not `entityName`. Agent
 * ids are either numeric (catalog items) or slug-based (foundational agents, e.g.
 * `gid://gitlab/Ai::FoundationalChatAgent/chat`). A slug would make `entityId % 7` evaluate to
 * `NaN`, so we hash it into an integer to give each agent a distinct, deterministic color.
 *
 * @param {String} agentId - The agent's GraphQL global id.
 * @returns {Number} A non-negative integer suitable for GlAvatar's `entityId`.
 */
export const agentAvatarEntityId = (agentId) => {
  if (!agentId) return 0;

  const numericId = getIdFromGraphQLId(agentId);
  if (Number.isInteger(numericId)) return numericId;

  let hash = 0;
  for (let i = 0; i < agentId.length; i += 1) {
    // eslint-disable-next-line no-bitwise
    hash = (hash << 5) - hash + agentId.charCodeAt(i);
    // eslint-disable-next-line no-bitwise
    hash |= 0;
  }
  return Math.abs(hash);
};

export const concatStreamedChunks = (arr) => {
  if (!arr) return '';

  let end = arr.findIndex((el) => !el);

  if (end < 0) end = arr.length;

  return arr.slice(0, end).join('');
};

/**
 * Save duo agentic mode preference to both cookie and localStorage.
 * localStorage is used as fallback for mobile/private browsing where cookies may not work.
 *
 * @param {isAgenticMode} Boolean - Value to save
 * @returns {void}
 */
export const saveDuoAgenticModePreference = (isAgenticMode) => {
  setCookie(DUO_AGENTIC_MODE_COOKIE, isAgenticMode, {
    expires: DUO_AGENTIC_MODE_COOKIE_EXPIRATION,
  });
  saveStorageValue(DUO_AGENTIC_MODE_COOKIE, isAgenticMode);
};

/**
 * Switch duo chat based on agenticMode value and save to cookie based on
 * saveCookie value.
 *
 * @param {Object} params - The parameters object.
 * @param {boolean} params.agenticMode - The state of the agentic mode (true or false).
 * @param {boolean} params.saveCookie - Flag to save to cookie (true or false).
 * @returns {void}
 */

export const setAgenticMode = ({ agenticMode = true, saveCookie = false } = {}) => {
  duoChatGlobalState.chatMode = agenticMode ? CHAT_MODES.AGENTIC : CHAT_MODES.CLASSIC;

  if (saveCookie) {
    saveDuoAgenticModePreference(agenticMode);
  }
};

const openChatAndGetState = () => {
  // Get the current chat mode from global state
  const currentMode = duoChatGlobalState.chatMode;
  const isAgenticMode = currentMode === CHAT_MODES.AGENTIC;

  setAgenticMode({ agenticMode: isAgenticMode, saveCookie: false });

  eventHub.$emit(SHOW_NEW_CHAT);

  return {
    currentMode,
    isAgenticMode,
  };
};

/**
 * Sends a command to DuoChat to execute on. This should be use for
 * a single command.
 *
 * External triggers respect the current chat mode (Classic or Agentic).
 * In Classic mode, the question (slash command) is executed directly.
 * In Agentic mode, the agenticPrompt is sent as a user message to simulate
 * what the slash command would do.
 *
 * @param {question} String - Prompt to send to the chat endpoint (slash command for Classic mode)
 * @param {resourceId} String - Unique ID to bind the streaming
 * @param {variables} Object - Additional variables to pass to graphql chat mutation
 * @param {agenticPrompt} String - Optional prompt to use in Agentic mode (e.g., "troubleshoot this broken pipeline")
 * @param {agent} Object - Optional preferred agent specified by id or name (e.g., { id: "gid://gitlab/Ai::FoundationalChatAgent/security_analyst" } or { name: "Planner" })
 */
export const sendDuoChatCommand = ({
  question,
  resourceId,
  variables = {},
  agenticPrompt = null,
  agent = null,
} = {}) => {
  if (!question || !resourceId) {
    throw new Error('Both arguments `question` and `resourceId` are required');
  }

  const { isAgenticMode } = openChatAndGetState();

  window.requestIdleCallback(() => {
    // In Agentic mode, use the agenticPrompt if provided; otherwise fall back to the slash command
    const effectiveQuestion = isAgenticMode && agenticPrompt ? agenticPrompt : question;

    const stateOptions = {
      question: effectiveQuestion,
      resourceId,
      variables,
    };

    if (isAgenticMode && agent) {
      stateOptions.agent = agent;
    }

    duoChatGlobalState.commands = [...duoChatGlobalState.commands, stateOptions];
  });
};

export const focusDuoChatInput = () => {
  openChatAndGetState();

  duoChatGlobalState.focusChatInput = true;
};

/**
 * Opens DuoChat with a specific agent pre-selected, without auto-sending a message.
 * Optionally customises the empty-state welcome message shown before the user has typed anything.
 *
 * @param {Object} agent - Agent to pre-select, specified by id or name (e.g., { name: 'Planner' })
 * @param {string} resourceId - Unique ID to bind any future streaming
 * @param {string|null} welcomeMessage - Override for the empty-state title shown in the chat panel
 * @param {Array|null} predefinedPrompts - Example questions shown in the empty state
 * @param {Array|null} additionalContext - additional_context envelopes attached to every
 *   startWorkflow request for this session (e.g. a form_context envelope so the agent knows
 *   which form it is editing). Each item is `{ category, content, metadata }`.
 */
export const openDuoChatWithAgent = ({
  agent,
  resourceId,
  welcomeMessage = null,
  predefinedPrompts = null,
  additionalContext = null,
} = {}) => {
  if (!agent || !resourceId) {
    throw new Error('Both arguments `agent` and `resourceId` are required');
  }

  setAgenticMode();
  openChatAndGetState();

  const enqueue = () => {
    duoChatGlobalState.commands = [
      ...duoChatGlobalState.commands,
      {
        agent,
        resourceId,
        autoSend: false,
        welcomeMessage,
        predefinedPrompts,
        additionalContext,
      },
    ];
  };

  if (window.requestIdleCallback) {
    window.requestIdleCallback(enqueue);
  } else {
    setTimeout(enqueue, 0);
  }
};

export const clearDuoChatCommands = () => {
  duoChatGlobalState.commands = [];
};

/**
 * Converts a text string into a URL-friendly format for event tracking.
 *
 * - Converts to lowercase
 * - Removes special characters
 * - Replaces spaces with underscores
 * - Limits length to 50 characters
 *
 * @param {string} text - The text to convert
 * @returns {string} The formatted event label
 */
export const generateEventLabelFromText = (text) => {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .substring(0, 50);
};

export const utils = {
  concatStreamedChunks,
  generateEventLabelFromText,
};

export const initializeChatMode = () => {
  const savedModeCookie = getCookie(DUO_AGENTIC_MODE_COOKIE);
  const savedModeStorage = getStorageValue(DUO_AGENTIC_MODE_COOKIE);
  const savedMode = savedModeCookie || (savedModeStorage.exists ? savedModeStorage.value : null);

  // Default to agentic mode unless explicitly disabled via cookie/storage
  if (savedMode !== 'false') {
    duoChatGlobalState.chatMode = CHAT_MODES.AGENTIC;
  } else {
    duoChatGlobalState.chatMode = CHAT_MODES.CLASSIC;
  }
};

initializeChatMode();
