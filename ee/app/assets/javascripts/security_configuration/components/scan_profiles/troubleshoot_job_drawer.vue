<script>
import { GlButton, GlDrawer, GlLoadingIcon } from '@gitlab/ui';
import GlSafeHtmlDirective from '~/vue_shared/directives/safe_html';
import { SCAN_PROFILE_CATEGORIES, SCAN_PROFILE_I18N } from '~/security_configuration/constants';
import { s__, sprintf } from '~/locale';
import TroubleshootJobData from 'ee/security_configuration/components/scan_profiles/troubleshoot_job_data.vue';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';
import scannerJobDetailsQuery from 'ee/security_configuration/graphql/scan_profiles/scanner_job_details.query.graphql';
import { DUO_CHAT_QUICK_ACTION_TROUBLESHOOT, i18n } from 'ee/ai/constants';
import duoChatAvailableQuery from 'ee/ai/graphql/duo_chat_available.query.graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import DuoChatQuickAction from 'ee/ai/shared/widgets/duo_chat_quick_action.vue';

export default {
  name: 'TroubleshootJobDrawer',
  components: {
    TroubleshootJobData,
    GlDrawer,
    GlButton,
    GlLoadingIcon,
    DuoChatQuickAction,
  },
  directives: {
    SafeHtml: GlSafeHtmlDirective,
  },
  props: {
    openDrawer: {
      type: Boolean,
      required: false,
      default: false,
    },
    jobData: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    buildId: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      required: true,
    },
    scanType: {
      type: String,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  emits: ['close-drawer'],
  data() {
    return {
      fetchedJobData: null,
      errorMessage: null,
      duoChatAvailable: false,
    };
  },
  apollo: {
    fetchedJobData: {
      query: scannerJobDetailsQuery,
      skip() {
        return this.hasJobData;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          id: this.buildId,
        };
      },
      update: (data) => data?.project?.job,
      error() {
        this.errorMessage = SCAN_PROFILE_I18N.errorLoadingJobData;
      },
    },
    duoChatAvailable: {
      query: duoChatAvailableQuery,
      update(data) {
        return data?.currentUser?.duoChatAvailable ?? false;
      },
      error(error) {
        this.duoChatAvailable = false;
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    hasJobData() {
      return Object.keys(this.jobData).length > 0;
    },
    isLoading() {
      return this.$apollo.queries.fetchedJobData?.loading;
    },
    resolvedJobData() {
      return this.hasJobData ? this.jobData : this.fetchedJobData || {};
    },
    drawerTitle() {
      return `${this.getScannerMetadata(this.scanType).displayName} ${s__('SecurityProfiles|failure')}`;
    },
    isJobDataReady() {
      return Object.keys(this.resolvedJobData).length > 0;
    },
    getJobId() {
      return getIdFromGraphQLId(this.buildId);
    },
    resourceId() {
      return convertToGraphQLId(TYPENAME_CI_BUILD, this.getJobId);
    },
  },
  methods: {
    traceSummary() {
      return this.resolvedJobData.trace?.htmlSummary || s__('SecurityProfiles|No job log');
    },
    getScannerMetadata(scanType) {
      return SCAN_PROFILE_CATEGORIES[scanType] || {};
    },
    viewJobButtonTitle() {
      return sprintf(s__('SecurityProfiles|View job #%{jobId}'), {
        jobId: this.getJobId,
      });
    },
  },
  duoQuickAction: {
    classicQuickAction: DUO_CHAT_QUICK_ACTION_TROUBLESHOOT,
    command: {
      agenticPrompt: i18n.AGENTIC_PROMPT_TROUBLESHOOT_PIPELINE,
    },
    tracking: {
      label: 'security_scan_troubleshoot_duo',
    },
    buttonOptions: { variant: 'confirm' },
  },
  allowedConfig: {
    ALLOWED_TAGS: ['span', 'br', 'div'],
  },
};
</script>

<template>
  <gl-drawer :open="openDrawer" :header-sticky="true" @close="$emit('close-drawer')">
    <template #title>
      <span class="gl-font-bold">{{ drawerTitle }}</span>
    </template>

    <div v-if="errorMessage" data-testid="error-message">{{ errorMessage }}</div>
    <gl-loading-icon v-else-if="isLoading" size="lg" class="gl-my-5" data-testid="drawer-loader" />
    <template v-else-if="isJobDataReady">
      <h3 class="gl-my-2 !gl-pb-0 gl-text-lg">
        {{ s__('SecurityProfiles|Job details') }}
      </h3>
      <troubleshoot-job-data
        :name="resolvedJobData.name"
        :status="status"
        :duration="resolvedJobData.duration"
        :source="resolvedJobData.source"
        :finished-at="resolvedJobData.finishedAt"
        :web-path="resolvedJobData.webPath"
        :pipeline="resolvedJobData.pipeline"
        :is-drawer="true"
      />
      <h3 v-if="resolvedJobData.failureMessage" class="gl-m-2 !gl-pb-0 gl-text-lg">
        {{ s__('SecurityProfiles|Failure summary') }}
      </h3>
      <div
        v-if="resolvedJobData.failureMessage"
        class="gl-m-2 !gl-pb-0"
        data-testid="failure-message"
      >
        {{ resolvedJobData.failureMessage }}
      </div>
      <h3
        v-if="resolvedJobData.trace?.htmlSummary && !resolvedJobData.failureMessage"
        class="gl-m-2 !gl-pb-0 gl-text-lg"
      >
        {{ s__('SecurityProfiles|Root cause') }}
      </h3>
      <pre
        v-if="resolvedJobData.trace?.htmlSummary && !resolvedJobData.failureMessage"
        class="gl-m-2 gl-w-full gl-border-none !gl-pb-0 gl-text-left"
      >
        <code
          v-safe-html:[$options.allowedConfig]="traceSummary()" class="gl-bg-inherit gl-p-0"
          data-testid="job-trace-summary">
        </code>
      </pre>
    </template>

    <template #footer>
      <div v-if="isJobDataReady" class="gl-flex gl-gap-3">
        <duo-chat-quick-action
          v-if="duoChatAvailable"
          data-testid="duo-button"
          class="gl-grow"
          :button-options="$options.duoQuickAction.buttonOptions"
          :button-text="s__('SecurityProfiles|Troubleshoot failure')"
          :resource-id="resourceId"
          :tracking-info="$options.duoQuickAction.tracking"
          :command="$options.duoQuickAction.command"
          :classic-quick-action="$options.duoQuickAction.classicQuickAction"
        />
        <gl-button data-testid="view-job-button" class="gl-grow" :href="resolvedJobData.webPath"
          >{{ viewJobButtonTitle() }}
        </gl-button>
      </div>
    </template>
  </gl-drawer>
</template>
