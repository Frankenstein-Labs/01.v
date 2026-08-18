<script>
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { DUO_CHAT_AGENT_GITLAB_DUO } from 'ee/ai/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import DuoChatQuickAction from './duo_chat_quick_action.vue';
import DuoWorkflowAction from './duo_workflow_action.vue';

export default {
  name: 'DuoWorkItemToMrAction',
  components: {
    DuoChatQuickAction,
    DuoWorkflowAction,
  },
  mixins: [glFeatureFlagsMixin(), glListenersMixin],
  agentPrivileges: [1, 2, 3, 4, 5],
  generateMrTracking: { label: 'generate_mr_with_duo' },
  SOURCE: 'work_item_to_merge_request',
  props: {
    generateMrButtonOptions: {
      type: Object,
      required: false,
      default: () => ({ size: 'medium', variant: 'default', category: 'primary' }),
    },
    projectPath: {
      type: String,
      required: true,
    },
    workItemIid: {
      type: [String, Number],
      required: true,
    },
    workItemType: {
      type: String,
      required: false,
      default: 'issue',
    },
    workItemWebUrl: {
      type: String,
      required: true,
    },
    additionalGoalContext: {
      type: String,
      required: false,
      default: '',
    },
    runDuoDeveloperInChat: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    useAgenticFlowTool() {
      if (!this.glFeatures.agenticFoundationalFlowTool) {
        return false;
      }

      return this.runDuoDeveloperInChat;
    },
    goal() {
      const username = window.gon?.current_username || '';
      const resourceName = this.workItemType?.toLowerCase() || 'issue';
      /* eslint-disable @gitlab/require-i18n-strings -- LLM prompt content sent to Duo Developer agent, not user-facing UI */
      const baseGoal = [
        `@${username} assigned you to solve the following ${resourceName}: ${this.workItemWebUrl}`,
        '',
        'Fetch the details and understand the problem thoroughly before writing any code. Consider what might be causing the issue and where in the codebase the relevant logic lives. If there are multiple possible approaches, reason about the tradeoffs and pick the simplest one that fully addresses the issue. Implement your solution, verify it works, then create a merge request with your changes.',
        '',
        `When you have completed your work, @mention @${username} in a comment on the issue to notify them. Assign @${username} as the assignee of the merge request unless told differently.`,
      ].join('\n');
      /* eslint-enable @gitlab/require-i18n-strings */

      if (this.additionalGoalContext) {
        return `${this.additionalGoalContext}\n\n${baseGoal}`;
      }
      return baseGoal;
    },
    generateMrCommand() {
      /* eslint-disable @gitlab/require-i18n-strings -- LLM prompt content sent to Duo Chat agent, not user-facing UI */
      return {
        agenticPrompt: `Start the duo developer flow with the following goal: ${this.goal}`,
        agent: { name: DUO_CHAT_AGENT_GITLAB_DUO },
      };
      /* eslint-enable @gitlab/require-i18n-strings */
    },
  },
};
</script>
<template>
  <duo-chat-quick-action
    v-if="useAgenticFlowTool"
    :button-text="s__('DuoAgentPlatform|Implement')"
    :resource-id="workItemIid"
    :command="generateMrCommand"
    :tracking-info="$options.generateMrTracking"
    :button-options="generateMrButtonOptions"
    v-bind="$attrs"
    v-on="glListeners()"
  />
  <duo-workflow-action
    v-else
    :project-path="projectPath"
    :hover-message="s__('DuoAgentPlatform|Implement work item with GitLab Duo')"
    :goal="goal"
    workflow-definition="developer/v1"
    :agent-privileges="$options.agentPrivileges"
    :work-item-iid="workItemIid"
    :size="generateMrButtonOptions.size"
    :variant="generateMrButtonOptions.variant"
    :category="generateMrButtonOptions.category"
    :source="$options.SOURCE"
    v-bind="$attrs"
    v-on="glListeners()"
  >
    <slot>{{ s__('DuoAgentPlatform|Implement work item') }}</slot>
  </duo-workflow-action>
</template>
