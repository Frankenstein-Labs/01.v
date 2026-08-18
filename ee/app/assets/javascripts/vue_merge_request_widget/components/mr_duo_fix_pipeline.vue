<script>
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import { relativePathToAbsolute } from '~/lib/utils/url_utility';
import { buildFixPipelineContext } from '~/ci/utils';
import { FIX_PIPELINE_AGENT_PRIVILEGES } from '~/duo_agent_platform/constants';
import { s__ } from '~/locale';
import getFixPipelineWorkflowsQuery from '../queries/get_fix_pipeline_workflows.query.graphql';

export default {
  name: 'MrWidgetPipelineDuoAction',
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
  },
  apollo: {
    workflows: {
      query: getFixPipelineWorkflowsQuery,
      skip() {
        return !this.getPipelinePath;
      },
      variables() {
        return {
          projectPath: this.targetProjectFullPath,
          search: this.getPipelinePath,
        };
      },
      update(data) {
        return data?.project?.duoWorkflowWorkflows?.edges ?? [];
      },
    },
  },
  data() {
    return {
      workflows: [],
      agentFlowStarted: false,
    };
  },
  computed: {
    getPipelinePath() {
      if (this.pipeline?.path) {
        return relativePathToAbsolute(this.pipeline.path, gon.gitlab_url);
      }
      return null;
    },
    getAdditionalContext() {
      return buildFixPipelineContext({
        source: this.pipeline?.source,
        sourceBranch: this.sourceBranch,
        mergeRequestPath: relativePathToAbsolute(this.mergeRequestPath, gon.gitlab_url),
      });
    },
    fixPipelineText() {
      return s__('Pipeline|Fix pipeline with Duo');
    },
    isAlreadyRun() {
      return this.agentFlowStarted || this.workflows.length > 0;
    },
    hoverMessage() {
      return this.isAlreadyRun
        ? s__(
            'Pipeline|A Fix pipeline session is already running or completed for this pipeline. Push a new commit or re-run the pipeline to try again.',
          )
        : this.fixPipelineText;
    },
  },
  FIX_PIPELINE_AGENT_PRIVILEGES,
  SOURCE: 'merge_request_fix_pipeline',
};
</script>

<template>
  <div class="gl-pt-2">
    <duo-workflow-action
      workflow-definition="fix_pipeline/v1"
      :goal="getPipelinePath"
      :project-path="targetProjectFullPath"
      :hover-message="hoverMessage"
      :source-branch="sourceBranch"
      :agent-privileges="$options.FIX_PIPELINE_AGENT_PRIVILEGES"
      :additional-context="getAdditionalContext"
      :source="$options.SOURCE"
      :disabled="isAlreadyRun"
      @agent-flow-started="agentFlowStarted = true"
    >
      {{ fixPipelineText }}
    </duo-workflow-action>
  </div>
</template>
