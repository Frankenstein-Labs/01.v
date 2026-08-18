<script>
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import { relativePathToAbsolute } from '~/lib/utils/url_utility';
import { buildFixPipelineContext } from '~/ci/utils';
import { RESOLVE_DEPENDENCY_BUMP_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import { s__ } from '~/locale';
import getDependencyBumpBreakingChangesAvailable from '../queries/get_dependency_bump_breaking_changes_available.query.graphql';

export default {
  name: 'MrWidgetPipelineDuoResolveDependencyBump',
  components: {
    DuoWorkflowAction,
  },
  props: {
    pipeline: {
      type: Object,
      required: true,
    },
    mergeRequestPath: {
      type: String,
      required: true,
    },
    targetProjectFullPath: {
      type: String,
      required: true,
    },
    sourceBranch: {
      type: String,
      required: true,
    },
    iid: {
      type: [Number, String],
      required: false,
      default: null,
    },
  },
  apollo: {
    isAvailable: {
      query: getDependencyBumpBreakingChangesAvailable,
      variables() {
        return {
          projectPath: this.targetProjectFullPath,
          iid: `${this.iid}`,
        };
      },
      skip() {
        return !this.targetProjectFullPath || !this.iid;
      },
      update(data) {
        return Boolean(data?.project?.mergeRequest?.duoDependencyBumpBreakingChangesAvailable);
      },
      error() {
        this.isAvailable = false;
      },
    },
  },
  data() {
    return {
      isAvailable: false,
    };
  },
  computed: {
    pipelineUrl() {
      if (this.pipeline?.path) {
        return relativePathToAbsolute(this.pipeline.path, gon.gitlab_url);
      }
      return null;
    },
    additionalContext() {
      return buildFixPipelineContext({
        source: this.pipeline?.source,
        sourceBranch: this.sourceBranch,
        mergeRequestPath: relativePathToAbsolute(this.mergeRequestPath, gon.gitlab_url),
      });
    },
    buttonText() {
      return s__('Pipeline|Resolve breaking changes with Duo');
    },
  },
  RESOLVE_DEPENDENCY_BUMP_AGENT_PRIVILEGES,
  SOURCE: 'merge_request_dependency_bump',
};
</script>

<template>
  <div v-if="isAvailable && pipelineUrl" class="gl-pt-2">
    <duo-workflow-action
      workflow-definition="resolve_dependency_bump/experimental"
      :goal="pipelineUrl"
      :project-path="targetProjectFullPath"
      :hover-message="buttonText"
      :source-branch="sourceBranch"
      :merge-request-id="iid"
      :agent-privileges="$options.RESOLVE_DEPENDENCY_BUMP_AGENT_PRIVILEGES"
      :additional-context="additionalContext"
      :source="$options.SOURCE"
    >
      {{ buttonText }}
    </duo-workflow-action>
  </div>
</template>
