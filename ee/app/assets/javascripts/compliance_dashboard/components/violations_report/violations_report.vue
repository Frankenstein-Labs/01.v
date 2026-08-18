<script>
import { GlSprintf, GlAlert, GlLink, GlToggle } from '@gitlab/ui';
import Tracking from '~/tracking';
import { FEEDBACK_ISSUE_URL_VIOLATIONS } from 'ee/compliance_dashboard/constants';
import { s__ } from '~/locale';
import ComplianceViolationsReport from './report.vue';
import ComplianceViolationsReportV2 from './report_v2.vue';

export default {
  name: 'ComplianceViolationsReportContainer',
  components: {
    ComplianceViolationsReport,
    ComplianceViolationsReportV2,
    GlToggle,
    GlAlert,
    GlLink,
    GlSprintf,
  },
  mixins: [Tracking.mixin()],
  inject: ['violationsV2Enabled'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  emits: ['changed'],
  data() {
    return {
      showBanner: this.violationsV2Enabled,
      showNewReport: this.violationsV2Enabled,
    };
  },
  methods: {
    updateReportVersion(value) {
      this.track('toggle_violations_report_version');
      this.$emit('changed', 'report_version', {
        showNewReport: value,
      });
      this.showNewReport = !this.showNewReport;
    },
  },
  i18n: {
    feedbackTitle: s__(
      'ComplianceReport|We are replacing the violations report with a new version that includes enhanced features for your compliance workflow.',
    ),
    feedbackText: s__(
      'ComplianceReport|Have questions or thoughts on the new improvements? %{linkStart}Please provide feedback on your experience%{linkEnd}.',
    ),
    toggleLabel: s__('ComplianceReport|Show old report'),
  },
  FEEDBACK_ISSUE_URL_VIOLATIONS,
};
</script>

<template>
  <div>
    <gl-alert v-if="showBanner" variant="info" dismissible @dismiss="showBanner = false">
      <div>
        {{ $options.i18n.feedbackTitle }}
        <gl-sprintf :message="$options.i18n.feedbackText">
          <template #link="{ content }">
            <gl-link :href="$options.FEEDBACK_ISSUE_URL_VIOLATIONS" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </div>
      <div class="gl-mt-4 gl-flex gl-items-center">
        <gl-toggle
          :value="!showNewReport"
          :label="$options.i18n.toggleLabel"
          label-position="left"
          @change="updateReportVersion"
        />
      </div>
    </gl-alert>
    <compliance-violations-report-v2
      v-if="showNewReport"
      :group-path="groupPath"
      :project-path="projectPath"
    />
    <compliance-violations-report v-else :group-path="groupPath" :project-path="projectPath" />
  </div>
</template>
