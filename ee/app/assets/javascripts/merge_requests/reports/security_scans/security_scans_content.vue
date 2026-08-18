<script>
import { defineAsyncComponent } from 'vue';
import { GlButton, GlDisclosureDropdown, GlLink } from '@gitlab/ui';
import { joinPaths, visitUrl } from '~/lib/utils/url_utility';
import { helpPagePath } from '~/helpers/help_page_helper';
import StatusIcon from '~/vue_merge_request_widget/components/widget/status_icon.vue';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import { i18n } from 'ee/vue_merge_request_widget/widgets/security_reports/i18n';
import SummaryText from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import ReportDetails from 'ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_report_details.vue';

export default {
  name: 'SecurityScansContent',
  components: {
    StatusIcon,
    SummaryText,
    SummaryHighlights,
    HelpPopover,
    GlButton,
    GlDisclosureDropdown,
    GlLink,
    ReportDetails,
    VulnerabilityFindingModal: defineAsyncComponent(
      () => import('ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue'),
    ),
  },
  inject: [
    'findingReports',
    'totalNewFindings',
    'highlights',
    'topLevelErrorMessage',
    'hasAtLeastOneReportWithMaxNewVulnerabilities',
    'hasFindingReportErrors',
    'hasFindings',
    'hasEnabledScans',
    'isLoadingScans',
    'loadingMessage',
    'statusMessage',
    'statusIconName',
    'updateFindingState',
  ],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      modalData: null,
    };
  },
  computed: {
    shouldShowReportDetails() {
      return (
        !this.loadingMessage &&
        !this.statusMessage &&
        !this.topLevelErrorMessage &&
        (this.hasFindings || this.hasFindingReportErrors)
      );
    },
    pipelineSecurityPath() {
      if (!this.mr?.pipeline?.path) {
        return undefined;
      }
      return joinPaths(this.mr.pipeline.path, 'security');
    },
    modalPipelineIid() {
      const iid = this.modalData?.vulnerability?.foundByPipelineIid;
      return iid ? Number(iid) : null;
    },
    branchRef() {
      return this.mr.sourceBranch;
    },
    pipelineFindingsDropdownItems() {
      return [
        {
          text: i18n.viewAllPipelineFindings,
          href: this.pipelineSecurityPath,
        },
      ];
    },
  },
  methods: {
    setModalData(finding) {
      this.modalData = {
        error: null,
        title: finding.title,
        vulnerability: finding,
      };
    },
    clearModalData() {
      this.modalData = null;
    },
    onFindingStateChange(state) {
      this.updateFindingState(this.modalData.vulnerability.uuid, state);
    },
    handleResolveWithAiSuccess(commentUrl) {
      this.clearModalData();
      visitUrl(commentUrl);
    },
  },
  i18n,
  helpPopover: {
    options: { title: i18n.helpPopoverTitle },
    learnMorePath: helpPagePath('user/application_security/detect/security_scanning_results', {
      anchor: 'merge-request-reports',
    }),
  },
};
</script>

<template>
  <div>
    <vulnerability-finding-modal
      v-if="modalData"
      :finding-uuid="modalData.vulnerability.uuid"
      :pipeline-iid="modalPipelineIid"
      :branch-ref="branchRef"
      :project-full-path="mr.targetProjectFullPath"
      :source-project-full-path="mr.sourceProjectFullPath"
      :show-ai-resolution="true"
      :merge-request-id="mr.id"
      data-testid="vulnerability-finding-modal"
      @hidden="clearModalData"
      @dismissed="onFindingStateChange('dismissed')"
      @detected="onFindingStateChange('detected')"
      @resolve-with-ai-success="handleResolveWithAiSuccess"
    />
    <div class="gl-flex gl-px-5 gl-py-4" data-testid="security-scans-summary">
      <status-icon :name="$options.name" :is-loading="isLoadingScans" :icon-name="statusIconName" />
      <span v-if="loadingMessage">{{ loadingMessage }}</span>
      <div v-else-if="statusMessage" class="gl-flex gl-grow gl-justify-between">
        <span>{{ statusMessage }}</span>
        <div
          v-if="pipelineSecurityPath && hasEnabledScans"
          class="gl-flex gl-items-start @md/panel:gl-items-center"
        >
          <help-popover
            icon="information-o"
            :options="$options.helpPopover.options"
            class="gl-mr-3"
          >
            <p class="gl-mb-0">{{ $options.i18n.helpPopoverContent }}</p>
            <gl-link :href="$options.helpPopover.learnMorePath" target="_blank" class="gl-text-sm">
              {{ __('Learn more') }}
            </gl-link>
          </help-popover>
          <gl-disclosure-dropdown
            :items="pipelineFindingsDropdownItems"
            :toggle-text="$options.i18n.viewAllPipelineFindings"
            icon="ellipsis_v"
            no-caret
            category="tertiary"
            placement="bottom-end"
            text-sr-only
            size="small"
            toggle-class="!gl-p-2"
            class="gl-block @md/panel:!gl-hidden"
          />
          <gl-button :href="pipelineSecurityPath" class="gl-hidden @md/panel:gl-inline-flex">
            {{ $options.i18n.viewAllPipelineFindings }}
          </gl-button>
        </div>
      </div>
      <div v-else class="gl-flex gl-grow gl-justify-between">
        <div>
          <summary-text
            :total-new-vulnerabilities="totalNewFindings"
            :is-loading="false"
            :show-at-least-hint="hasAtLeastOneReportWithMaxNewVulnerabilities"
          />
          <summary-highlights v-if="totalNewFindings > 0" :highlights="highlights" />
        </div>
        <div v-if="pipelineSecurityPath" class="gl-flex gl-items-start @md/panel:gl-items-center">
          <help-popover
            icon="information-o"
            :options="$options.helpPopover.options"
            class="gl-mr-3"
          >
            <p class="gl-mb-0">{{ $options.i18n.helpPopoverContent }}</p>
            <gl-link :href="$options.helpPopover.learnMorePath" target="_blank" class="gl-text-sm">
              {{ __('Learn more') }}
            </gl-link>
          </help-popover>
          <gl-disclosure-dropdown
            :items="pipelineFindingsDropdownItems"
            :toggle-text="$options.i18n.viewAllPipelineFindings"
            icon="ellipsis_v"
            no-caret
            category="tertiary"
            placement="bottom-end"
            text-sr-only
            size="small"
            toggle-class="!gl-p-2"
            class="gl-block @md/panel:!gl-hidden"
          />
          <gl-button :href="pipelineSecurityPath" class="gl-hidden @md/panel:gl-inline-flex">
            {{ $options.i18n.viewAllPipelineFindings }}
          </gl-button>
        </div>
      </div>
    </div>
    <template v-if="shouldShowReportDetails">
      <report-details
        v-for="report in findingReports"
        :key="report.reportType"
        :report="report"
        :mr="mr"
        :widget-name="$options.name"
        is-reports-page
        @modal-data="setModalData"
      />
    </template>
  </div>
</template>
