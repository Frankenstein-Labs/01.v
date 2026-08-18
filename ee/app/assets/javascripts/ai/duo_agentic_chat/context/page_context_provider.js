import {
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
  AI_CONTEXT_ID_PAGE_CONTEXT,
} from 'ee/ai/constants';
import { s__ } from '~/locale';
import { getPagePath } from '../utils/page_utils';

export class PageContextProvider {
  constructor({ projectPath } = {}) {
    this.projectPath = projectPath;
  }

  async getItems(contextInjectionState) {
    if (!contextInjectionState?.[AI_CONTEXT_ID_PAGE_CONTEXT]?.pageChanged) {
      return [];
    }
    if (contextInjectionState?.[this.constructor.name]?.hasAlreadyProvided) {
      return [];
    }

    // Once the current page context is injected, no need to inject the same context in following conversation.
    // eslint-disable-next-line no-param-reassign
    contextInjectionState[this.constructor.name] = { hasAlreadyProvided: true };

    const contextParts = [
      `<current_gitlab_page_url>${typeof window !== 'undefined' && window.location ? window.location.href : ''}</current_gitlab_page_url>`,
      `<current_gitlab_page_title>${typeof document !== 'undefined' ? document.title : ''}</current_gitlab_page_title>`,
    ];

    const pageContext = contextParts.join('\n');
    const pagePath = getPagePath();

    return [
      {
        id: AI_CONTEXT_ID_PAGE_CONTEXT,
        content: pageContext,
        category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_REPOSITORY,
        metadata: JSON.stringify({
          title: s__('DuoAgenticChat|Current page'),
          enabled: true,
          icon: 'link',
          secondaryText: `${s__('DuoAgenticChat|Page context')} ${pagePath}`,
          subType: 'open_tab',
          subTypeLabel: s__('DuoAgenticChat|Current page'),
          projectPath: this.projectPath,
          pagePath,
        }),
      },
    ];
  }
}
