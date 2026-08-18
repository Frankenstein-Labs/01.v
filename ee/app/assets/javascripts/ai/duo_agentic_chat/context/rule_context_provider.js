import {
  DUO_WORKFLOW_ADDITIONAL_CONTEXT_USER_RULE,
  AI_CONTEXT_ID_PAGE_CONTEXT,
  AI_CONTEXT_ID_AGENT_MD,
  AI_CONTEXT_ID_CHAT_RULE,
  AGENTS_MD,
  CHAT_RULES_MD,
} from 'ee/ai/constants';
import { s__ } from '~/locale';
import getRuleContent from '../../graphql/rule_content.query.graphql';
import { captureExceptionForDuoChat } from '../observability/sentry_utils';

/*
This class is the Web Agentic Chat version of RuleContextProvider.
https://gitlab.com/gitlab-org/editor-extensions/gitlab-lsp/-/blob/main/packages/lib_ai_context/src/node/providers/rule.ts
*/
export class RuleContextProvider {
  constructor(apollo, { projectPath } = {}) {
    this.apollo = apollo;
    this.projectPath = projectPath;
  }

  async getItems(contextInjectionState) {
    if (!contextInjectionState?.[AI_CONTEXT_ID_PAGE_CONTEXT]?.projectChanged) {
      return [];
    }
    if (contextInjectionState?.[this.constructor.name]?.hasAlreadyProvided) {
      return [];
    }

    // Once the current project context is injected, no need to inject the same context in following conversation.
    // eslint-disable-next-line no-param-reassign
    contextInjectionState[this.constructor.name] = { hasAlreadyProvided: true };

    const rules = await this.fetchProjectRules();
    const items = [];

    if (rules[AI_CONTEXT_ID_AGENT_MD]) {
      items.push(rules[AI_CONTEXT_ID_AGENT_MD]);
    } else if (contextInjectionState[AI_CONTEXT_ID_AGENT_MD]?.oid) {
      items.push(this.createAgentMdItem());
    }

    if (rules[AI_CONTEXT_ID_CHAT_RULE]) {
      items.push(rules[AI_CONTEXT_ID_CHAT_RULE]);
    } else if (contextInjectionState[AI_CONTEXT_ID_CHAT_RULE]?.oid) {
      items.push(this.createChatRuleItem());
    }

    return items;
  }

  async fetchProjectRules() {
    if (!this.projectPath) {
      return {};
    }

    const rules = {};
    let blobs = [];

    try {
      const result = await this.apollo.query({
        query: getRuleContent,
        variables: {
          projectPath: this.projectPath,
          paths: [AGENTS_MD, `.gitlab/duo/${CHAT_RULES_MD}`],
        },
        fetchPolicy: 'network-only',
      });

      blobs = result?.data?.project?.repository?.blobs?.nodes || [];
    } catch (error) {
      captureExceptionForDuoChat(error);
      return {};
    }

    blobs.forEach((blob) => {
      switch (blob.name) {
        case AGENTS_MD:
          rules[AI_CONTEXT_ID_AGENT_MD] = this.createAgentMdItem(blob);
          break;
        case CHAT_RULES_MD:
          rules[AI_CONTEXT_ID_CHAT_RULE] = this.createChatRuleItem(blob);
          break;
        default:
          break;
      }
    });

    return rules;
  }

  createAgentMdItem(blob) {
    const content = blob
      ? `Apply the following project-specific AGENTS.md rules to this and following messages. These rules supersede any previously provided in <${AI_CONTEXT_ID_AGENT_MD}> tags:\n${blob.rawBlob}`
      : `Ignore any instructions previously provided in <${AI_CONTEXT_ID_AGENT_MD}> tags. There are no project-specific agent md rules at this page.`;

    return {
      id: AI_CONTEXT_ID_AGENT_MD,
      content,
      category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_USER_RULE,
      metadata: JSON.stringify({
        title: blob
          ? s__('DuoAgenticChat|AGENTS.md')
          : s__('DuoAgenticChat|Ignore previous AGENTS.md'),
        icon: 'document',
        enabled: true,
        subType: 'user_rule',
        subTypeLabel: blob
          ? `${this.projectPath} ${s__('DuoAgenticChat|AGENTS.md')}`
          : s__('DuoAgenticChat|AGENTS.md was not found in this page'),
        secondaryText: blob
          ? s__('DuoAgenticChat|AGENTS.md included')
          : s__('DuoAgenticChat|Prompted to ignore it'),
        oid: blob?.oid || '',
      }),
    };
  }

  createChatRuleItem(blob) {
    const content = blob
      ? `Apply the following project-specific chat rules to this and following messages. These rules supersede any previously provided in <${AI_CONTEXT_ID_CHAT_RULE}> tags:\n${blob.rawBlob}`
      : `Ignore any instructions previously provided in <${AI_CONTEXT_ID_CHAT_RULE}> tags. There are no project-specific chat rules at this page.`;

    return {
      id: AI_CONTEXT_ID_CHAT_RULE,
      content,
      category: DUO_WORKFLOW_ADDITIONAL_CONTEXT_USER_RULE,
      metadata: JSON.stringify({
        title: blob
          ? s__('DuoAgenticChat|chat-rules.md')
          : s__('DuoAgenticChat|Ignore previous chat-rules.md'),
        icon: 'document',
        enabled: true,
        subType: 'user_rule',
        subTypeLabel: blob
          ? `${this.projectPath} ${s__('DuoAgenticChat|chat-rules.md')}`
          : s__('DuoAgenticChat|chat-rules.md was not found in this page'),
        secondaryText: blob
          ? s__('DuoAgenticChat|chat-rules.md included')
          : s__('DuoAgenticChat|Prompted to ignore it'),
        oid: blob?.oid || '',
      }),
    };
  }
}
