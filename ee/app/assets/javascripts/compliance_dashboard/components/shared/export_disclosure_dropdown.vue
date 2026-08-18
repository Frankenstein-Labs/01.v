<script>
import {
  GlDisclosureDropdown,
  GlDisclosureDropdownItem,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlTooltipDirective,
} from '@gitlab/ui';

import { INPUT_DEBOUNCE, CUSTODY_REPORT_PARAMETER } from 'ee/compliance_dashboard/constants';
import { isValidSha1Hash } from '~/lib/utils/text_utility';
import { s__ } from '~/locale';

export default {
  name: 'ReportsExportApp',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormInput,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    mergeCommitsCsvExportPath: {
      type: String,
      required: false,
      default: null,
    },
    projectFrameworksCsvExportPath: {
      type: String,
      required: false,
      default: null,
    },
    complianceStatusReportExportPath: {
      type: String,
      required: false,
      default: null,
    },
    complianceViolationsCsvExportPath: {
      type: String,
      required: false,
      default: null,
    },
    violationsCsvExportPath: {
      type: String,
      required: false,
      default: null,
    },
    adherencesCsvExportPath: {
      type: String,
      required: false,
      default: null,
    },
    frameworksCsvExportPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      exportCustodyCommitDisclosure: false,
      validMergeCommitHash: null,
    };
  },
  computed: {
    legacyViolationsTitle() {
      if (this.complianceViolationsCsvExportPath) {
        return this.$options.i18n.legacyViolationsExportTitle;
      }

      return this.$options.i18n.violationsExportTitle;
    },
    exportItems() {
      const items = [];

      if (this.complianceStatusReportExportPath) {
        items.push({
          value: 'compliance_status_report_export',
          text: this.$options.i18n.complianceStatusReportExportTitle,
          href: this.complianceStatusReportExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_compliance_status_report',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.complianceStatusReport} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      if (this.adherencesCsvExportPath) {
        items.push({
          value: 'adherences_export',
          text: this.$options.i18n.adherencesExportTitle,
          href: this.adherencesCsvExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_all_adherences',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.adherence} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      if (this.complianceViolationsCsvExportPath) {
        items.push({
          value: 'compliance_violations_export',
          text: this.$options.i18n.complianceViolationsExportTitle,
          href: this.complianceViolationsCsvExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_all_compliance_violations',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.violations} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      if (this.violationsCsvExportPath) {
        items.push({
          value: 'violations_export',
          text: this.legacyViolationsTitle,
          href: this.violationsCsvExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_all_violations',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.legacyViolations} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      if (this.frameworksCsvExportPath) {
        items.push({
          value: 'frameworks_export',
          text: this.$options.i18n.frameworksExportTitle,
          href: this.frameworksCsvExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_all_frameworks',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.frameworks} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      if (this.projectFrameworksCsvExportPath) {
        items.push({
          value: 'project_frameworks_export',
          text: this.$options.i18n.projectFrameworksExportTitle,
          href: this.projectFrameworksCsvExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_all_project_frameworks',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.projectFrameworks} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      if (this.mergeCommitsCsvExportPath) {
        items.push({
          value: 'custody_commit_export',
          text: this.$options.i18n.custodyCommitsExportTitle,
          href: this.mergeCommitsCsvExportPath,
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_merge_commits',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.mergeCommits} ${this.$options.i18n.tooltipTexts.ending}`,
        });

        items.push({
          value: 'custody-commit-export',
          text: this.$options.i18n.custodyCommitExportTitle,
          action: () => {
            this.exportCustodyCommitDisclosure = true;
          },
          extraAttrs: {
            'data-track-action': 'click_export',
            'data-track-label': 'export_merge_commit',
          },
          tooltipText: `${this.$options.i18n.tooltipTexts.mergeCommitsByCommit} ${this.$options.i18n.tooltipTexts.ending}`,
        });
      }

      return items;
    },
    exportDropdownTitle() {
      return this.exportCustodyCommitDisclosure
        ? this.$options.i18n.custodyCommitExportTitle
        : this.$options.i18n.defaultExportDropdownTitle;
    },
    mergeCommitButtonDisabled() {
      return !this.validMergeCommitHash;
    },
  },
  methods: {
    onInput(value) {
      this.validMergeCommitHash = isValidSha1Hash(value);
    },
  },

  i18n: {
    defaultExportDropdownTitle: s__(
      'Compliance Center Export|Send email of the chosen report as CSV',
    ),
    adherencesExportTitle: s__('Compliance Center Export|Export standards adherence report'),
    frameworksExportTitle: s__('Compliance Center Export|Export frameworks report'),
    complianceViolationsExportTitle: s__(
      'Compliance Center Export|Export compliance violations report',
    ),
    violationsExportTitle: s__('Compliance Center Export|Export merge request violations report'),
    legacyViolationsExportTitle: s__(
      'Compliance Center Export|Export merge request violations report (legacy)',
    ),
    complianceStatusReportExportTitle: s__('Compliance Center Export|Export status report'),
    projectFrameworksExportTitle: s__('Compliance Center Export|Export list of project frameworks'),
    custodyCommitsExportTitle: s__('Compliance Center Export|Export chain of custody report'),
    custodyCommitExportTitle: s__(
      'Compliance Center Export|Export custody report of a specific commit',
    ),
    mergeCommitExampleLabel: s__('Compliance Center Export|Example: 2dc6aa3'),
    mergeCommitInvalidMessage: s__('Compliance Center Export|Invalid hash'),
    mergeCommitButtonText: s__('Compliance Center Export|Export custody report'),
    tooltipTexts: {
      violations: s__('Compliance Center Export|Export compliance violations as a CSV file.'),
      legacyViolations: s__(
        'Compliance Center Export|Export merge request violations as a CSV file.',
      ),
      adherence: s__(
        'Compliance Center Export|Export contents of the standards adherence report as a CSV file.',
      ),
      frameworks: s__(
        'Compliance Center Export|Export contents of the compliance frameworks report as a CSV file.',
      ),
      complianceStatusReport: s__(
        'Compliance Center Export|Export contents of the status report as a CSV file.',
      ),
      projectFrameworks: s__(
        'Compliance Center Export|Export a list of compliance frameworks for a project as a CSV file.',
      ),
      mergeCommits: s__(
        'Compliance Center Export|Export chain of custody report as a CSV file (limited to 15MB).',
      ),
      mergeCommitsByCommit: s__(
        'Compliance Center Export|Export chain of custody report of a specific commit as a CSV file (limited to 15MB).',
      ),
      ending: s__('Compliance Center Export|You will be emailed after the export is processed.'),
    },
  },
  inputDebounce: INPUT_DEBOUNCE,
  custodyReportParamater: CUSTODY_REPORT_PARAMETER,
};
</script>
<template>
  <gl-disclosure-dropdown
    fluid-width
    bordered
    icon="export"
    toggle-text="Export"
    data-testid="exports-disclosure-dropdown"
  >
    <template #header>
      <div class="gl-border-b gl-border-b-dropdown gl-p-4">
        <span class="gl-font-bold">
          {{ exportDropdownTitle }}
        </span>
      </div>
    </template>

    <template v-if="exportCustodyCommitDisclosure">
      <gl-form :action="mergeCommitsCsvExportPath" class="gl-px-3" method="GET">
        <gl-form-group
          :invalid-feedback="$options.i18n.mergeCommitInvalidMessage"
          :state="validMergeCommitHash"
          label-size="sm"
          label-for="merge-commits-export-custody-report"
          class="gl-mb-2"
        >
          <gl-form-input
            id="merge-commits-export-custody-report"
            :name="$options.custodyReportParamater"
            :debounce="$options.inputDebounce"
            :placeholder="$options.i18n.mergeCommitExampleLabel"
            @input="onInput"
          />
        </gl-form-group>
        <div class="gl-float-right gl-my-3">
          <gl-button
            size="small"
            data-testid="merge-commit-cancel-button"
            @click="exportCustodyCommitDisclosure = false"
          >
            {{ __('Cancel') }}
          </gl-button>
          <gl-button
            size="small"
            type="submit"
            :disabled="mergeCommitButtonDisabled"
            variant="confirm"
            data-testid="merge-commit-submit-button"
            class="disable-hover"
            data-track-action="click_export"
            data-track-label="export_custody_report"
            >{{ $options.i18n.mergeCommitButtonText }}</gl-button
          >
        </div>
      </gl-form>
    </template>
    <template v-for="(item, index) in exportItems" v-else>
      <gl-disclosure-dropdown-item
        :key="index"
        v-gl-tooltip="{
          title: item.tooltipText,
          boundary: 'viewport',
          placement: 'left',
          customClass: 'gl-pointer-events-none',
        }"
        :item="item"
      />
    </template>
  </gl-disclosure-dropdown>
</template>
