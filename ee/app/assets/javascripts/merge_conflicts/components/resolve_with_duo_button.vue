<script>
import DuoWorkflowAction from 'ee_component/ai/shared/widgets/duo_workflow_action.vue';
import { DUO_WORKFLOW_DEVELOPER_DEFINITION } from 'ee/ai/constants';

export default {
  name: 'ResolveWithDuoButton',
  components: {
    DuoWorkflowAction,
  },
  props: {
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    category: {
      type: String,
      required: false,
      default: 'primary',
    },
    variant: {
      type: String,
      required: false,
      default: 'default',
    },
    size: {
      type: String,
      required: false,
      default: 'medium',
    },
  },
  computed: {
    goal() {
      return `
        Resolve the merge conflicts in merge request '${this.mr.targetProjectFullPath}!${this.mr.iid}'.

        <scope>
        1. Only modify files that contain unresolved conflict markers — the set reported by 'git diff --name-only --diff-filter=U' after attempting the merge.
        2. Do NOT use 'git add .' or 'git add -A'. Stage each conflicted file individually by its exact path.
        3. If your final commit would touch any file outside that conflicted set, post a comment beginning with "⚠️ Needs review:" that lists the unexpected files, then exit without pushing.
        </scope>

        <role>
        Your role is to reconcile the two branches' existing changes — not to introduce new behavior. When the branches disagree on the same thing, pick the MR's intent as described in its title, description, and commits.

        When one branch's changes are purely cosmetic (whitespace, quote style, idiomatic refactoring), preserve those alongside the other branch's semantic changes — that's not a behavior change.

        If a resolution is genuinely ambiguous — delete/modify, incompatible add/add — keep the MR mergeable and begin the summary with "⚠️ Needs review:" plus a one-line explanation.
        </role>

        Directly commit and push. Post a summary comment when done.
      `;
    },
  },
  WORKFLOW_DEFINITION: DUO_WORKFLOW_DEVELOPER_DEFINITION,
  SOURCE: 'merge_request_code_conflict',
};
</script>

<template>
  <duo-workflow-action
    v-if="mr.canResolveWithAi"
    :project-path="mr.targetProjectFullPath"
    :goal="goal"
    :hover-message="
      s__('MergeConflict|Use GitLab Duo to automatically analyze and resolve merge conflicts')
    "
    :source-branch="mr.sourceBranch"
    :merge-request-id="mr.iid"
    :workflow-definition="$options.WORKFLOW_DEFINITION"
    :source="$options.SOURCE"
    :size="size"
    :category="category"
    :variant="variant"
  >
    <span class="gl-hidden @md/panel:gl-inline-flex">{{
      s__('MergeConflict|Resolve with GitLab Duo')
    }}</span>
  </duo-workflow-action>
</template>
