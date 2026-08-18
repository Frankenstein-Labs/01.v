<script>
import { SIMPLE_BLOB_VIEWER } from '~/blob/components/constants';
import DuoWorkflowAction from 'ee/ai/shared/widgets/duo_workflow_action.vue';
import CeBlobHeader from '~/blob/components/blob_header.vue';
import duoWorkflowActionQuery from 'ee/repository/queries/duo_workflow_action.query.graphql';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'BlobHeader',
  components: {
    DuoWorkflowAction,
    CeBlobHeader,
  },
  mixins: [glFeatureFlagMixin(), glListenersMixin, glSlotsMixin],
  SOURCE: 'convert_platform_ci_pipeline',
  props: {
    blob: {
      type: Object,
      required: true,
    },
    hideViewerSwitcher: {
      type: Boolean,
      required: false,
      default: false,
    },
    isBinary: {
      type: Boolean,
      required: false,
      default: false,
    },
    activeViewerType: {
      type: String,
      required: false,
      default: SIMPLE_BLOB_VIEWER,
    },
    hasRenderError: {
      type: Boolean,
      required: false,
      default: false,
    },
    showPath: {
      type: Boolean,
      required: false,
      default: true,
    },
    showPathAsLink: {
      type: Boolean,
      required: false,
      default: false,
    },
    overrideCopy: {
      type: Boolean,
      required: false,
      default: false,
    },
    showForkSuggestion: {
      type: Boolean,
      required: false,
      default: false,
    },
    showWebIdeForkSuggestion: {
      type: Boolean,
      required: false,
      default: false,
    },
    projectPath: {
      type: String,
      required: false,
      default: '',
    },
    projectId: {
      type: String,
      required: false,
      default: '',
    },
    showBlameToggle: {
      type: Boolean,
      required: false,
      default: false,
    },
    showBlamePopover: {
      type: Boolean,
      required: false,
      default: false,
    },
    showBlobSize: {
      type: Boolean,
      required: false,
      default: true,
    },
    showBlameInfo: {
      type: Boolean,
      required: false,
      default: false,
    },
    editButtonVariant: {
      type: String,
      required: false,
      default: 'confirm',
    },
    currentRef: {
      type: String,
      required: true,
    },
  },
  apollo: {
    duoWorkflowData: {
      query: duoWorkflowActionQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          filePath: [this.blob.path],
          ref: this.currentRef,
        };
      },
      skip() {
        if (this.blob?.fileType !== 'jenkinsfile') {
          return true;
        }

        return !this.projectPath || !this.blob?.path;
      },
      update(data) {
        return data?.project?.repository?.blobs?.nodes?.[0] || null;
      },
      error(error) {
        captureException(error, {
          tags: {
            vue_component: 'BlobHeader',
          },
        });
      },
    },
  },
  data() {
    return {
      duoWorkflowData: null,
      // eslint-disable-next-line @gitlab/require-i18n-strings
      SOURCE_PLATFORM_NAME: 'Jenkins', // MR 2 will replace with a per-fileType lookup map.
    };
  },
  computed: {
    agentPrivileges() {
      return [1, 2, 3, 5];
    },
    showDuoWorkflowAction() {
      return this.duoWorkflowData?.showDuoWorkflowAction;
    },
    getAdditionalContext() {
      return [
        {
          Category: 'agent_user_environment',
          Content: JSON.stringify({
            source_branch: this.currentRef,
          }),
          Metadata: '{}',
        },
      ];
    },
    duoWorkflowDefinition() {
      return this.glFeatures.duoConvertCiUseDeveloperFlow ? 'developer/v1' : 'convert_to_gl_ci/v1';
    },
    duoWorkflowGoal() {
      if (!this.glFeatures.duoConvertCiUseDeveloperFlow) {
        return this.blob.path;
      }
      return this.buildConversionGoal(this.SOURCE_PLATFORM_NAME, this.blob.path);
    },
  },
  methods: {
    buildConversionGoal(platform, filePath) {
      return [
        `Convert the ${platform} CI pipeline configuration at \`${filePath}\` to a GitLab CI/CD pipeline.`,
        '',
        '1. Read the source file. Identify any files it depends on (shared libraries, reusable workflows, orbs, composite actions, included templates, helper scripts, etc.) and read those too. Convert those dependencies as well, so the resulting pipeline is self-contained or uses GitLab equivalents (`include:`, `extends:`, components from the GitLab CI Catalog).',
        '2. Generate an equivalent `.gitlab-ci.yml` at the repository root that preserves stages, jobs, dependencies, parallel execution, and conditional logic. Map vendor-specific concepts (GitHub Actions secrets, Jenkins agents, CircleCI orbs, Azure pools, etc.) to their GitLab equivalents.',
        '3. Validate the generated YAML by running `glab ci lint .gitlab-ci.yml` (or the project-scoped equivalent). If `glab ci lint` reports errors, fix them and re-run until lint passes.',
        `4. Open a merge request titled "Convert ${platform} CI to GitLab CI" with the converted file(s). In the MR description, summarize any non-obvious mapping decisions and any features that could not be translated 1:1.`,
      ].join('\n');
    },
  },
};
</script>
<template>
  <ce-blob-header v-bind="$props" v-on="glListeners()">
    <template #ee-duo-workflow-action>
      <duo-workflow-action
        v-if="showDuoWorkflowAction"
        :project-path="projectPath"
        :hover-message="__('Convert Jenkins to GitLab CI/CD using Duo')"
        :goal="duoWorkflowGoal"
        :source-branch="currentRef"
        :workflow-definition="duoWorkflowDefinition"
        :agent-privileges="agentPrivileges"
        :additional-context="getAdditionalContext"
        :source="$options.SOURCE"
        size="medium"
        >{{ __('Convert to GitLab CI/CD') }}</duo-workflow-action
      >
    </template>

    <template v-if="glSlots().prepend" #prepend>
      <slot name="prepend"></slot>
    </template>

    <template v-if="glSlots().actions" #actions>
      <slot name="actions"></slot>
    </template>

    <template v-if="glSlots()['orbit-action']" #orbit-action>
      <slot name="orbit-action"></slot>
    </template>
  </ce-blob-header>
</template>
