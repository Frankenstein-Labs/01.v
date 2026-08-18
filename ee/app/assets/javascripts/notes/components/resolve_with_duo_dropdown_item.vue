<script>
import DuoWorkflowAction from 'ee_component/ai/shared/widgets/duo_workflow_action.vue';
import { s__ } from '~/locale';
import { RESOLVE_DISCUSSION_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import { DUO_WORKFLOW_DEVELOPER_DEFINITION } from 'ee/ai/constants';

export default {
  name: 'ResolveWithDuoDropdownItem',
  components: {
    DuoWorkflowAction,
  },
  props: {
    discussion: {
      type: Object,
      required: true,
    },
    sourceBranch: {
      type: String,
      required: false,
      default: '',
    },
    iid: {
      type: [String, Number],
      required: false,
      default: null,
    },
  },
  emits: ['triggered', 'triggering'],
  computed: {
    goal() {
      return `
        Resolve discussion '${this.discussion.id}' in merge request '${this.projectPath}!${this.iid}'.

        Use the GitLab API to fetch the discussion and understand what the reviewer is asking for. Address the feedback without introducing new behaviour beyond what is requested.

        Make the change on branch '${this.sourceBranch}', commit and push. Then reply to discussion '${this.discussion.id}' with a one-line summary of what you changed and resolve the thread.
      `.trim();
    },
    projectPath() {
      return document.body.dataset.projectFullPath ?? '';
    },
  },
  i18n: {
    buttonLabel: s__('DuoAgentPlatform|Resolve with GitLab Duo'),
  },
  WORKFLOW_DEFINITION: DUO_WORKFLOW_DEVELOPER_DEFINITION,
  AGENT_PRIVILEGES: RESOLVE_DISCUSSION_AGENT_PRIVILEGES,
  SOURCE: 'merge_request_resolve_discussion',
};
</script>
<template>
  <duo-workflow-action
    render-as="dropdown-item"
    :merge-request-id="iid"
    :workflow-definition="$options.WORKFLOW_DEFINITION"
    :project-path="projectPath"
    :goal="goal"
    :source-branch="sourceBranch"
    :agent-privileges="$options.AGENT_PRIVILEGES"
    :source="$options.SOURCE"
    @triggering="$emit('triggering')"
    @triggered="$emit('triggered')"
  >
    {{ $options.i18n.buttonLabel }}
  </duo-workflow-action>
</template>
