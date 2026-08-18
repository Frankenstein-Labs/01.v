import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { logError } from '~/lib/logger';
import { eventHub, QUEUE_CHAT_COMMAND } from '../events/panel';
import {
  isMaximizedVar,
  infoToggleStatesVar,
  agentSessionStatusVar,
  panelTitleVar,
  panelSubtitleVar,
} from './state';

export const setMaximized = (value) => {
  return isMaximizedVar(value);
};

export const toggleMaximized = () => {
  const current = isMaximizedVar();
  return isMaximizedVar(!current);
};

export const getInfoToggleVisible = (sessionId, context = 'default') => {
  const states = infoToggleStatesVar();
  const key = `${context}:${sessionId}`;
  return states[key] ?? false;
};

export const toggleInfoToggle = (sessionId, context = 'default') => {
  const states = infoToggleStatesVar();
  const key = `${context}:${sessionId}`;
  const newValue = !getInfoToggleVisible(sessionId, context);
  infoToggleStatesVar({
    ...states,
    [key]: newValue,
  });
  return newValue;
};

export const setInfoToggleVisible = (sessionId, value, context = 'default') => {
  const states = infoToggleStatesVar();
  const key = `${context}:${sessionId}`;
  infoToggleStatesVar({
    ...states,
    [key]: value,
  });
};

export const setAgentSessionStatus = (status) => {
  return agentSessionStatusVar(status);
};

export const setPanelTitle = (title) => {
  return panelTitleVar(title);
};

export const setPanelSubtitle = (subtitle) => {
  return panelSubtitleVar(subtitle);
};

const setupPanelEvents = () => {
  eventHub.$on(QUEUE_CHAT_COMMAND, async (command) => {
    try {
      const { sendDuoChatCommand } = await import('../utils');
      sendDuoChatCommand(command);
    } catch (e) {
      logError(
        'Failed to import `sendDuoChatCommand`function from ee/app/assets/javascripts/ai/utils.js',
        e,
      );
    }
  });
};

export const cacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        isMaximized: {
          read() {
            return isMaximizedVar();
          },
        },
        infoToggleStates: {
          read() {
            return infoToggleStatesVar();
          },
        },
        agentSessionStatus: {
          read() {
            return agentSessionStatusVar();
          },
        },
        panelTitle: {
          read() {
            return panelTitleVar();
          },
        },
        panelSubtitle: {
          read() {
            return panelSubtitleVar();
          },
        },
      },
    },
    // AiAdditionalContext.id is a discriminator constant (e.g. "page-context"),
    // not a unique row id — multiple messages legitimately carry context items
    // with the same id but distinct per-message metadata. Normalising by id
    // would collapse them into a single shared cache entry and let one
    // message's context overwrite another's.
    AiAdditionalContext: {
      keyFields: false,
    },
  },
};

export const createApolloProvider = () => {
  setupPanelEvents();

  const defaultClient = createDefaultClient(
    {},
    {
      cacheConfig,
    },
  );

  return new VueApollo({ defaultClient });
};
