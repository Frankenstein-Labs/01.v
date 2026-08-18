<script>
import { GlButton, GlLoadingIcon, GlPopover } from '@gitlab/ui';
import { s__ } from '~/locale';
import timeagoMixin from '~/vue_shared/mixins/timeago';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  SCAN_PROFILE_I18N,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
} from '~/security_configuration/constants';
import scannerJobDetailsQuery from 'ee/security_configuration/graphql/scan_profiles/scanner_job_details.query.graphql';
import TroubleshootJobData from './troubleshoot_job_data.vue';

export default {
  name: 'JobDetailsPopover',
  components: {
    GlButton,
    GlLoadingIcon,
    GlPopover,
    TroubleshootJobData,
  },
  mixins: [timeagoMixin],
  props: {
    buildId: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      required: true,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
    target: {
      type: String,
      required: true,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    show: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['open-drawer', 'mouseenter', 'mouseleave'],
  data() {
    return {
      jobData: {},
      errorMessage: null,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.jobData.loading;
    },
    redirectToJobPath() {
      return this.jobData?.webPath ? `${this.jobData.webPath}` : '#';
    },
    configurationButtonTitle() {
      if (this.isFailedOrWarningStatus())
        return this.$options.SCAN_PROFILE_I18N.troubleshootFailure;
      return `${s__('SecurityProfiles|View job #')}${getIdFromGraphQLId(this.buildId)}`;
    },
  },
  SCAN_PROFILE_I18N,
  apollo: {
    jobData: {
      query: scannerJobDetailsQuery,
      variables() {
        return { fullPath: this.projectFullPath, id: this.buildId };
      },
      update: (data) => {
        return data?.project?.job;
      },
      error() {
        this.errorMessage = SCAN_PROFILE_I18N.errorLoadingJobData;
      },
    },
  },
  methods: {
    isFailedOrWarningStatus() {
      return [SCAN_PROFILE_SCANNER_HEALTH_WARNING, SCAN_PROFILE_SCANNER_HEALTH_FAILED].includes(
        this.status,
      );
    },
    handleButtonClick() {
      if (this.isFailedOrWarningStatus()) {
        this.$emit('open-drawer', this.jobData);
      }
    },
  },
};
</script>

<template>
  <gl-popover :target="target" :title="title" :show="show" triggers="">
    <div
      data-testid="popover-content"
      @mouseenter="$emit('mouseenter')"
      @mouseleave="$emit('mouseleave')"
    >
      <template v-if="isLoading">
        <gl-loading-icon size="md" />
      </template>
      <template v-else-if="errorMessage">{{ errorMessage }}</template>
      <template v-else-if="jobData">
        <troubleshoot-job-data
          :name="jobData.name"
          :status="status"
          :duration="jobData.duration"
          :source="jobData.source"
          :pipeline="jobData.pipeline"
        />

        <gl-button
          :category="isFailedOrWarningStatus() ? 'primary' : 'secondary'"
          :variant="isFailedOrWarningStatus() ? 'confirm' : 'default'"
          class="gl-my-3 gl-w-full"
          size="small"
          :href="isFailedOrWarningStatus() ? undefined : redirectToJobPath"
          @click="handleButtonClick"
          >{{ configurationButtonTitle }}
        </gl-button>
      </template>
    </div>
  </gl-popover>
</template>
