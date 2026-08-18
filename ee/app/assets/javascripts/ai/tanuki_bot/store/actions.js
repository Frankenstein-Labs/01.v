import { GENIE_CHAT_MODEL_ROLES } from 'ee/ai/constants';
import * as types from './mutation_types';

const proxyMessageContent = (message, propsToUpdate) => {
  return {
    ...message,
    ...propsToUpdate,
    role: message.role || GENIE_CHAT_MODEL_ROLES.user,
  };
};

const commitMessage = (commit, messageData) => {
  const { errors = [], content = '' } = messageData || {};
  const msgContent = content || errors.join('; ');

  if (msgContent) {
    const message = proxyMessageContent(messageData, { content: msgContent });

    if (message.role.toLowerCase() === GENIE_CHAT_MODEL_ROLES.system) {
      commit(types.ADD_TOOL_MESSAGE, message);
    } else {
      commit(types.ADD_MESSAGE, message);
    }
  }
};

export const addDuoChatMessage = async ({ commit }, messageData = { content: '' }) => {
  commitMessage(commit, messageData);
};

export const setMessages = ({ commit }, messages = []) => {
  commit(types.CLEAN_MESSAGES);

  if (messages.length) {
    messages.forEach((msg) => {
      commitMessage(commit, msg);
    });
  }
};

export const setCurrentAgent = ({ commit }, agent = null) => {
  commit(types.STORE_CURRENT_AGENT, agent);
};
