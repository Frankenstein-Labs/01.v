/*
This class is the Web Agentic Chat version of SystemContextManager.
https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/blob/main/packages/lib_ai_context/src/system_context/system_context_manager.ts
*/

import {
  AI_CONTEXT_ID_PAGE_CONTEXT,
  AI_CONTEXT_ID_AGENT_MD,
  AI_CONTEXT_ID_CHAT_RULE,
} from 'ee/ai/constants';
import { getPagePath } from '../utils/page_utils';

function processAdditionalContext(state, message, paths) {
  const { pagePath, projectPath } = paths;

  for (const item of message.additional_context) {
    switch (item.id) {
      case AI_CONTEXT_ID_PAGE_CONTEXT:
        state[AI_CONTEXT_ID_PAGE_CONTEXT] ??= {
          pageChanged: item.metadata.pagePath !== pagePath,
          projectChanged: item.metadata.projectPath !== projectPath,
          currentPagePath: pagePath,
        };
        break;
      case AI_CONTEXT_ID_AGENT_MD:
        state[AI_CONTEXT_ID_AGENT_MD] ??= {
          oid: item.metadata.oid,
        };
        break;
      case AI_CONTEXT_ID_CHAT_RULE:
        state[AI_CONTEXT_ID_CHAT_RULE] ??= {
          oid: item.metadata.oid,
        };
        break;
      default:
        break;
    }
  }

  // No need to process further if these states have been fetched.
  if (
    state[AI_CONTEXT_ID_PAGE_CONTEXT] &&
    state[AI_CONTEXT_ID_AGENT_MD] &&
    state[AI_CONTEXT_ID_CHAT_RULE]
  ) {
    return false;
  }

  return true;
}

function setDefaultInjectionState(state, pagePath, projectPath) {
  if (!state[AI_CONTEXT_ID_PAGE_CONTEXT]) {
    state[AI_CONTEXT_ID_PAGE_CONTEXT] = {
      pageChanged: Boolean(pagePath),
      projectChanged: Boolean(projectPath),
    };
  }
}

export function getContextInjectionState(messages = [], projectPath) {
  const pagePath = getPagePath();
  const state = {};

  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const msg = messages[i];

    if (msg.message_type === 'user' && msg.additional_context) {
      if (!processAdditionalContext(state, msg, { pagePath, projectPath })) {
        break;
      }
    }
  }

  setDefaultInjectionState(state, pagePath, projectPath);

  return state;
}

export class SystemContextManager {
  constructor(providers = []) {
    this.providers = providers;
    this.contextInjectionState = null;
  }

  registerProvider(provider) {
    this.providers.push(provider);
  }

  async getSystemContextItems(messages, projectPath) {
    const availableProviders = this.providers;

    this.checkContextInjectionStateUpToDate();
    this.contextInjectionState ??= getContextInjectionState(messages, projectPath);

    const providerPromises = availableProviders.map(async (provider) => {
      try {
        return await provider.getItems(this.contextInjectionState);
      } catch (error) {
        return [];
      }
    });

    const allContextItems = await Promise.all(providerPromises);
    const flattenedItems = allContextItems.flat();

    return flattenedItems;
  }

  checkContextInjectionStateUpToDate() {
    /* Check if the cached context injection state is up-to-date.
       Some UI/SPA components allows users to change the page path withtout requesting Rails e.g. blob pages */
    const pagePath = getPagePath();

    if (this.contextInjectionState?.[AI_CONTEXT_ID_PAGE_CONTEXT]?.currentPagePath !== pagePath) {
      this.resetContextInjectionState();
    }
  }

  resetContextInjectionState() {
    this.contextInjectionState = null;
  }
}
