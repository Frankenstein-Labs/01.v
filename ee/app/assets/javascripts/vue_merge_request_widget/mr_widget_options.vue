<script>
import { defineAsyncComponent } from 'vue';
import { GlSprintf, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { s__ } from '~/locale';
import reportsMixin from 'ee/vue_shared/security_reports/mixins/reports_mixin';
import CEWidgetOptions from '~/vue_merge_request_widget/mr_widget_options.vue';
import MrWidgetAlertMessage from '~/vue_merge_request_widget/components/mr_widget_alert_message.vue';
import MrWidgetPipelineContainer from '~/vue_merge_request_widget/components/mr_widget_pipeline_container.vue';
import MrWidgetApprovals from 'ee_else_ce/vue_merge_request_widget/components/approvals/approvals.vue';
import MrWidgetAutoMergeEnabled from '~/vue_merge_request_widget/components/states/mr_widget_auto_merge_enabled.vue';
import MergeChecks from '~/vue_merge_request_widget/components/merge_checks.vue';
import ReadyToMerge from '~/vue_merge_request_widget/components/states/ready_to_merge.vue';
import Loading from '~/vue_merge_request_widget/components/loading.vue';
import MrWidgetPolicyViolation from './components/states/mr_widget_policy_violation.vue';
import MrWidgetGeoSecondaryNode from './components/states/mr_widget_secondary_geo_node.vue';
import MrWidgetSecurityPolicyPipelineNote from './components/mr_widget_security_policy_pipeline_note.vue';
import { SECURITY_POLICY_PIPELINE_CHECK, BLOCKING_STATUSES } from './components/checks/constants';
import WidgetContainer from './components/widget/app.vue';

export default {
  name: 'MRWidgetRootEE',
  components: {
    GlSprintf,
    GlLink,
    WidgetContainer,
    MrWidgetGeoSecondaryNode,
    MrWidgetPolicyViolation,
    MrWidgetAlertMessage,
    MrWidgetPipelineContainer,
    MrWidgetApprovals,
    MrWidgetAutoMergeEnabled,
    MrWidgetSecurityPolicyPipelineNote,
    Loading,
    MergeChecks,
    ReadyToMerge,
    AgentSessionsWidget: defineAsyncComponent(
      () => import('ee/vue_merge_request_widget/widgets/agent_sessions/index.vue'),
    ),
    BlockingMergeRequestsReport: defineAsyncComponent(
      () => import('./components/blocking_merge_requests/blocking_merge_requests_report.vue'),
    ),
  },
  manageStorageDocsMsg: s__(
    'mrWidget|To continue, %{docLinkStart}manage your storage usage%{docLinkEnd}.',
  ),
  manageStorageDocsLink: helpPagePath('user/storage_usage_quotas'),
  directives: {
    SafeHtml,
  },
  extends: CEWidgetOptions,
  mixins: [reportsMixin],
  computed: {
    mergeCheck() {
      return (
        (this.mergeChecksState?.mergeabilityChecks || []).find(
          (c) => c.identifier === SECURITY_POLICY_PIPELINE_CHECK,
        ) || null
      );
    },
    shouldShowSecurityPolicyPipelineNote() {
      const isBlocking = BLOCKING_STATUSES.includes(this.mergeCheck?.status);
      return Boolean(this.mr?.isPipelinePassing && isBlocking && this.mr?.securityPoliciesPath);
    },
  },
  methods: {
    // eslint-disable-next-line vue/no-unused-properties -- overrides parent CEWidgetOptions method, called by parent component lifecycle
    getServiceEndpoints(store) {
      const base = CEWidgetOptions.methods.getServiceEndpoints(store);

      return {
        ...base,
        apiApprovalSettingsPath: store.apiApprovalSettingsPath,
      };
    },
  },
};
</script>
<template>
  <div v-if="!loading" id="widget-state" class="mr-state-widget gl-mt-5">
    <agent-sessions-widget v-if="mr && mr.iid" :mr="mr" />
    <header v-if="shouldRenderCollaborationStatus" class="mr-section-container gl-overflow-hidden">
      <mr-widget-alert-message type="info">
        {{ s__('mrWidget|Members who can merge are allowed to add commits.') }}
      </mr-widget-alert-message>
    </header>
    <mr-widget-pipeline-container
      v-if="shouldRenderPipelines"
      :mr="mr"
      :class="{ '!gl-rounded-b-none': shouldShowSecurityPolicyPipelineNote }"
      data-testid="pipeline-container"
    />
    <mr-widget-security-policy-pipeline-note v-if="shouldShowSecurityPolicyPipelineNote" :mr="mr" />
    <mr-widget-approvals v-if="shouldRenderApprovals" :mr="mr" :service="service" />
    <widget-container v-if="mr" :mr="mr" />
    <div class="mr-section-container">
      <template v-if="hasAlerts">
        <mr-widget-alert-message
          v-if="hasMergeError"
          type="danger"
          dismissible
          data-testid="merge-error"
          class="mr-widget-section gl-rounded-b-none gl-border-b-section"
        >
          <span>{{ mergeError }}</span>

          <gl-sprintf v-if="showManageStorageDocsLink" :message="$options.manageStorageDocsMsg">
            <template #docLink="{ content }">
              <gl-link :href="$options.manageStorageDocsLink" target="_blank">
                {{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </mr-widget-alert-message>
        <mr-widget-alert-message
          v-if="showMergePipelineForkWarning"
          type="warning"
          :help-path="mr.mergeRequestPipelinesHelpPath"
          class="mr-widget-section gl-rounded-b-none gl-border-b-section"
          data-testid="merge-pipeline-fork-warning"
        >
          {{
            s__(
              'mrWidget|If the last pipeline ran in the fork project, it may be inaccurate. Before merge, we advise running a pipeline in this project.',
            )
          }}
          <template #link-content>
            {{ __('Learn more') }}
          </template>
        </mr-widget-alert-message>
      </template>
      <blocking-merge-requests-report class="gl-border-b gl-border-b-section" :mr="mr" />

      <div class="mr-widget-section">
        <template v-if="mergeBlockedComponentVisible">
          <mr-widget-auto-merge-enabled
            v-if="autoMergeEnabled"
            :mr="mr"
            :service="service"
            class="gl-border-b gl-border-b-section"
          />
          <merge-checks
            :mr="mr"
            :service="service"
            :merge-checks-state="mergeChecksState"
            :is-loading-merge-checks="isLoadingMergeChecks"
          />
        </template>
        <component :is="componentName" v-else :mr="mr" :service="service" />
        <ready-to-merge v-if="mr.commitsCount" :mr="mr" :service="service" />
      </div>
    </div>
    <mr-widget-pipeline-container
      v-if="shouldRenderMergedPipeline"
      class="js-post-merge-pipeline"
      data-testid="merged-pipeline-container"
      :mr="mr"
      is-post-merge
    />
  </div>
  <loading v-else />
</template>
