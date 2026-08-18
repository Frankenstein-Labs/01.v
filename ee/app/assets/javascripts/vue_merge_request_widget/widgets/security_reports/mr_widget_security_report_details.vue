<script>
import {
  GlBadge,
  GlButton,
  GlIcon,
  GlLink,
  GlPopover,
  GlTabs,
  GlTab,
  GlAlert,
  GlSprintf,
} from '@gitlab/ui';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import { s__ } from '~/locale';
import MrWidgetRow from '~/vue_merge_request_widget/components/widget/widget_content_row.vue';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { helpPagePath } from '~/helpers/help_page_helper';
import { DynamicScroller, DynamicScrollerItem } from 'vendor/vue-virtual-scroller';
import { transformKeys } from '~/lib/utils/object_utils';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import SummaryText from './summary_text.vue';
import { i18n, popovers } from './i18n';
import { highlightsFromReport } from './utils';

const DIFF_BASED_TAB_INDEX = 0;
const FULL_SCAN_TAB_INDEX = 1;
const SEVERITY_LEVELS_UPPERCASE = transformKeys(SEVERITY_LEVELS, (key) => key.toUpperCase());

export default {
  name: 'MrWidgetSecurityReportDetails',
  SEVERITY_LEVELS_UPPERCASE,
  i18n,
  components: {
    MrWidgetRow,
    GlAlert,
    GlBadge,
    GlButton,
    GlIcon,
    GlLink,
    GlPopover,
    GlTabs,
    GlTab,
    GlSprintf,
    DynamicScroller,
    DynamicScrollerItem,
    SummaryText,
    SummaryHighlights,
  },
  mixins: [glAbilitiesMixin()],
  props: {
    report: {
      type: Object,
      required: true,
    },
    mr: {
      type: Object,
      required: true,
    },
    widgetName: {
      type: String,
      required: true,
    },
    isReportsPage: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['modal-data'],
  data() {
    return {
      tabIndex: this.isScanEnabled('partial') ? DIFF_BASED_TAB_INDEX : FULL_SCAN_TAB_INDEX,
    };
  },
  computed: {
    shouldShowDiffBasedHelperText() {
      return this.tabIndex === DIFF_BASED_TAB_INDEX;
    },
    shouldShowEmptyState() {
      if (this.tabIndex === FULL_SCAN_TAB_INDEX && !this.isScanEnabled('full')) {
        return true;
      }

      if (this.tabIndex === FULL_SCAN_TAB_INDEX) {
        return this.report.full?.numberOfNewFindings === 0;
      }

      return this.report.partial?.numberOfNewFindings === 0;
    },
    emptyStateMessage() {
      const fullScanEmpty =
        this.tabIndex === FULL_SCAN_TAB_INDEX && this.report.full?.numberOfNewFindings === 0;
      const diffScanEmpty =
        this.tabIndex === DIFF_BASED_TAB_INDEX && this.report.partial?.numberOfNewFindings === 0;

      if (fullScanEmpty || diffScanEmpty) {
        return s__('ciReport|No new vulnerabilities were found.');
      }

      if (this.tabIndex === FULL_SCAN_TAB_INDEX) {
        return s__('ciReport|Full scan is not enabled for this project.');
      }

      return '';
    },
    summaryTextError() {
      return this.report.full?.error || this.report.partial?.error;
    },
    summaryTextDesc() {
      return this.report.full?.reportTypeDescription || this.report.partial?.reportTypeDescription;
    },
    summaryTextTestId() {
      return this.report.full?.testId || this.report.partial?.testId;
    },
    displayPartialScans() {
      return this.isScanEnabled('partial');
    },
    totalNewFindings() {
      return (
        (this.report.partial?.numberOfNewFindings || 0) +
        (this.report.full?.numberOfNewFindings || 0)
      );
    },
    statusIconNameReportType() {
      if (this.totalNewFindings > 0 || this.summaryTextError) {
        return EXTENSION_ICONS.warning;
      }

      return EXTENSION_ICONS.success;
    },
    helpPopovers() {
      return {
        SAST: {
          options: { title: popovers.SAST_TITLE },
          content: { text: popovers.SAST_TEXT, learnMorePath: this.mr.sastHelp },
        },
        DAST: {
          options: { title: popovers.DAST_TITLE },
          content: { text: popovers.DAST_TEXT, learnMorePath: this.mr.dastHelp },
        },
        SECRET_DETECTION: {
          options: { title: popovers.SECRET_DETECTION_TITLE },
          content: {
            text: popovers.SECRET_DETECTION_TEXT,
            learnMorePath: this.mr.secretDetectionHelp,
          },
        },
        CONTAINER_SCANNING: {
          options: { title: popovers.CONTAINER_SCANNING_TITLE },
          content: {
            text: popovers.CONTAINER_SCANNING_TEXT,
            learnMorePath: this.mr.containerScanningHelp,
          },
        },
        DEPENDENCY_SCANNING: {
          options: { title: popovers.DEPENDENCY_SCANNING_TITLE },
          content: {
            text: popovers.DEPENDENCY_SCANNING_TEXT,
            learnMorePath: this.mr.dependencyScanningHelp,
          },
        },
        API_FUZZING: {
          options: { title: popovers.API_FUZZING_TITLE },
          content: {
            learnMorePath: this.mr.apiFuzzingHelp,
          },
        },
        COVERAGE_FUZZING: {
          options: { title: popovers.COVERAGE_FUZZING_TITLE },
          content: {
            learnMorePath: this.mr.coverageFuzzingHelp,
          },
        },
      };
    },
  },
  methods: {
    isScanEnabled(key) {
      return Object.keys(this.report?.[key] || {}).length > 0;
    },
    statusIconNameVulnerability(vuln) {
      const { severity } = vuln;
      const severityTitleCase = capitalizeFirstCharacter(severity.toLowerCase());
      return EXTENSION_ICONS[`severity${severityTitleCase}`];
    },
    isDismissed(vuln) {
      return vuln.state.toLowerCase() === 'dismissed';
    },
    setModalData(finding) {
      this.$emit('modal-data', finding);
    },
    isAiResolvable(vuln) {
      return vuln.aiResolutionEnabled && this.glAbilities.resolveVulnerabilityWithAi;
    },
    showAutoDismissPolicyBadge(vuln) {
      return vuln.matchesAutoDismissPolicy && !this.isDismissed(vuln);
    },
    getAiResolvableBadgeId(uuid) {
      return `ai-resolvable-badge-${uuid}`;
    },
    getAutoDismissPolicyBadgeId(uuid) {
      return `auto-dismiss-policy-badge-${uuid}`;
    },
    tabTitle(scanType) {
      return this.report[scanType]?.numberOfNewFindings ?? '-';
    },
    hasScanTypeAnyNewOrFixedFindings(scanType) {
      return (
        this.report[scanType]?.numberOfNewFindings || this.report[scanType]?.numberOfFixedFindings
      );
    },
    highlightsFromReport,
  },
  aiResolutionHelpPopOver: {
    text: s__(
      'ciReport|GitLab Duo Vulnerability Resolution, an AI feature, can suggest a possible fix.',
    ),
    learnMorePath: helpPagePath('user/application_security/vulnerabilities/_index', {
      anchor: 'vulnerability-resolution-in-a-merge-request',
    }),
  },
  policyAutoDismissPopover: {
    text: s__('ciReport|Vulnerability was matched by a policy and will be auto-dismissed.'),
    learnMorePath: helpPagePath(
      'user/application_security/policies/vulnerability_management_policy',
      { anchor: 'auto-dismiss-policies' },
    ),
  },
  diffBasedScansLearnMorePath: helpPagePath('user/application_security/sast/gitlab_advanced_sast', {
    anchor: 'turn-on-diff-based-scanning',
  }),
  tabs: [
    { title: i18n.partialScan, scanType: 'partial' },
    { title: i18n.fullScan, scanType: 'full' },
  ],
};
</script>

<template>
  <mr-widget-row
    :widget-name="widgetName"
    :level="2"
    :status-icon-name="statusIconNameReportType"
    :help-popover="helpPopovers[report.reportType]"
    :data-testid="`report-${report.reportType}`"
  >
    <template #header>
      <div>
        <summary-text
          :total-new-vulnerabilities="totalNewFindings"
          :is-loading="false"
          :error="summaryTextError"
          :scanner="summaryTextDesc"
          :data-testid="summaryTextTestId"
          show-at-least-hint
        />
        <summary-highlights
          v-if="totalNewFindings > 0"
          :highlights="highlightsFromReport(report)"
        />
      </div>
    </template>
    <template #body>
      <gl-tabs
        v-model="tabIndex"
        content-class="gl-pt-0"
        class="gl-mt-1 gl-w-full"
        :class="{
          '[&_.gl-tabs-wrapper]:gl-hidden': !displayPartialScans,
        }"
      >
        <gl-tab v-for="tab in $options.tabs" :key="tab.title">
          <template v-if="displayPartialScans" #title>
            <span>{{ tab.title }}</span>
            <gl-badge class="gl-ml-2">{{ tabTitle(tab.scanType) }}</gl-badge>
          </template>

          <slot>
            <gl-alert
              v-if="shouldShowDiffBasedHelperText"
              variant="info"
              class="gl-mb-5"
              :dismissible="false"
            >
              <gl-sprintf :message="$options.i18n.usingDiffBasedScans">
                <template #link="{ content }">
                  <gl-link :href="$options.diffBasedScansLearnMorePath">{{ content }}</gl-link>
                </template>
              </gl-sprintf>
            </gl-alert>

            <p
              v-if="shouldShowEmptyState"
              class="gl-mb-0 gl-mt-4 gl-text-subtle"
              data-testid="empty-state"
            >
              {{ emptyStateMessage }}
            </p>

            <div v-if="hasScanTypeAnyNewOrFixedFindings(tab.scanType)" class="gl-mt-2 gl-w-full">
              <dynamic-scroller
                :items="report[tab.scanType].findings"
                :min-item-size="32"
                :style="isReportsPage ? {} : { maxHeight: '170px' }"
                data-testid="dynamic-content-scroller"
                key-field="uuid"
                class="gl-pr-5"
              >
                <template #default="{ item: vuln, active, index }">
                  <dynamic-scroller-item :item="vuln" :active="active">
                    <strong
                      v-if="report[tab.scanType].numberOfNewFindings > 0 && index === 0"
                      data-testid="new-findings-title"
                      class="gl-mt-2 gl-block"
                      >{{ $options.i18n.new }}</strong
                    >
                    <strong
                      v-if="
                        report[tab.scanType].numberOfFixedFindings > 0 &&
                        report[tab.scanType].numberOfNewFindings === index
                      "
                      data-testid="fixed-findings-title"
                      class="gl-mt-2 gl-block"
                      >{{ $options.i18n.fixed }}</strong
                    >
                    <mr-widget-row
                      :key="vuln.uuid"
                      :level="3"
                      :widget-name="widgetName"
                      :status-icon-name="statusIconNameVulnerability(vuln)"
                      class="gl-mt-2"
                    >
                      <template #body>
                        <div class="gl-flex gl-min-w-0 gl-flex-wrap gl-items-baseline gl-gap-1">
                          <span class="gl-shrink-0"
                            >{{ $options.SEVERITY_LEVELS_UPPERCASE[vuln.severity] }}:</span
                          >
                          <gl-button
                            variant="link"
                            class="gl-ml-1 gl-min-w-0 gl-overflow-hidden gl-text-ellipsis gl-whitespace-nowrap"
                            @click="setModalData(vuln)"
                            >{{ vuln.title }}
                          </gl-button>
                          <gl-badge
                            v-if="isDismissed(vuln)"
                            class="gl-shrink-0"
                            data-testid="dismissed-badge"
                            >{{ $options.i18n.dismissed }}
                          </gl-badge>
                          <template v-if="isAiResolvable(vuln)">
                            <gl-badge
                              :id="getAiResolvableBadgeId(vuln.uuid)"
                              variant="info"
                              class="gl-shrink-0"
                              data-testid="ai-resolvable-badge"
                            >
                              <gl-icon :size="12" name="tanuki-ai" />
                            </gl-badge>
                            <gl-popover
                              trigger="hover focus"
                              placement="top"
                              boundary="viewport"
                              :target="getAiResolvableBadgeId(vuln.uuid)"
                              :data-testid="`ai-resolvable-badge-popover-${vuln.uuid}`"
                            >
                              {{ $options.aiResolutionHelpPopOver.text }}
                              <gl-link :href="$options.aiResolutionHelpPopOver.learnMorePath"
                                >{{ __('Learn more') }}
                              </gl-link>
                            </gl-popover>
                          </template>
                          <template v-if="showAutoDismissPolicyBadge(vuln)">
                            <gl-badge
                              :id="getAutoDismissPolicyBadgeId(vuln.uuid)"
                              variant="info"
                              class="gl-shrink-0"
                              data-testid="auto-dismiss-policy-badge"
                            >
                              <gl-icon :size="12" name="flag" />
                            </gl-badge>
                            <gl-popover
                              trigger="hover focus"
                              placement="top"
                              boundary="viewport"
                              :target="getAutoDismissPolicyBadgeId(vuln.uuid)"
                              :data-testid="`auto-dismiss-policy-badge-popover-${vuln.uuid}`"
                            >
                              {{ $options.policyAutoDismissPopover.text }}
                              <gl-link :href="$options.policyAutoDismissPopover.learnMorePath"
                                >{{ __('Learn more') }}
                              </gl-link>
                            </gl-popover>
                          </template>
                        </div>
                      </template>
                    </mr-widget-row>
                  </dynamic-scroller-item>
                </template>
              </dynamic-scroller>
            </div>
          </slot>
        </gl-tab>
      </gl-tabs>
    </template>
  </mr-widget-row>
</template>
