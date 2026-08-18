<script>
import { GlTab, GlTabs, GlButton, GlPopover, GlSprintf, GlLink, GlBadge } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import Tracking from '~/tracking';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import { isTopLevelGroup } from '../utils';
import {
  ROUTE_DASHBOARD,
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
  i18n,
} from '../constants';

import ReportsExport from './shared/export_disclosure_dropdown.vue';

export default {
  name: 'ComplianceReportsApp',
  components: {
    GlTabs,
    GlTab,
    GlButton,
    GlPopover,
    GlSprintf,
    GlLink,
    GlBadge,
    ReportsExport,
    PageHeading,
  },
  mixins: [Tracking.mixin(), glAbilitiesMixin()],
  inject: [
    'complianceStatusReportExportPath',
    'mergeCommitsCsvExportPath',
    'projectFrameworksCsvExportPath',
    'complianceViolationsCsvExportPath',
    'violationsCsvExportPath',
    'adherencesCsvExportPath',
    'frameworksCsvExportPath',
    'canAccessRootAncestorComplianceCenter',
    'designatedAsCsp',
  ],
  props: {
    availableTabs: {
      type: Array,
      required: true,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    rootAncestor: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isGroup() {
      return !this.projectPath;
    },
    isTopLevelGroup() {
      return isTopLevelGroup(this.groupPath, this.rootAncestor.path);
    },
    hasAtLeastOneExportAvailable() {
      return (
        this.complianceStatusReportExportPath ||
        this.projectFrameworksCsvExportPath ||
        this.mergeCommitsCsvExportPath ||
        this.violationsCsvExportPath ||
        this.adherencesCsvExportPath ||
        this.frameworksCsvExportPath
      );
    },
    tabs() {
      const tabConfigs = {
        [ROUTE_DASHBOARD]: {
          testId: 'dashboard-tab',
          title: i18n.overviewTab,
        },
        [ROUTE_STANDARDS_ADHERENCE]: {
          testId: 'standards-adherence-tab',
          title: i18n.standardsAdherenceTab,
        },
        [ROUTE_VIOLATIONS]: {
          testId: 'violations-tab',
          title: i18n.violationsTab,
        },
        [ROUTE_FRAMEWORKS]: {
          testId: 'frameworks-tab',
          title: i18n.frameworksTab,
        },
        [ROUTE_PROJECTS]: {
          testId: 'projects-tab',
          title: this.projectPath ? i18n.projectTab : i18n.projectsTab,
        },
      };

      return this.availableTabs.map((tabName) => {
        const tabConfig = tabConfigs[tabName];
        return {
          title: tabConfig.title,
          titleAttributes: { 'data-testid': tabConfig.testId },
          target: tabName,
          // eslint-disable-next-line @gitlab/require-i18n-strings
          contentTestId: `${tabConfig.testId}-content`,
        };
      });
    },
    tabIndex() {
      return this.tabs.findIndex((tab) => tab.target === this.$route.name);
    },
    canAdminComplianceFramework() {
      return this.glAbilities.adminComplianceFramework;
    },
  },
  methods: {
    goTo(name) {
      if (this.$route.name !== name) {
        this.$router.push({ name });

        this.track('click_report_tab', { label: name });
      }
    },
    newFramework() {
      this.$router.push({ name: ROUTE_NEW_FRAMEWORK });
    },
  },
  ROUTE_STANDARDS: ROUTE_STANDARDS_ADHERENCE,
  ROUTE_VIOLATIONS,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  i18n,
  documentationPath: helpPagePath('user/compliance/compliance_center/_index.md'),
};
</script>
<template>
  <div>
    <page-heading>
      <template #heading>
        <div class="gl-flex gl-items-center">
          <span>{{ $options.i18n.heading }}</span>
          <gl-badge v-if="designatedAsCsp" class="gl-ml-2" data-testid="csp-badge">
            {{ s__('SecurityOrchestration|Compliance and security policy group') }}
          </gl-badge>
        </div>
      </template>

      <template #description>
        <gl-sprintf :message="$options.i18n.subheading">
          <template #link="{ content }">
            <gl-link
              :href="$options.documentationPath"
              target="_blank"
              data-testid="subheading-docs-link"
              >{{ content }}</gl-link
            >
          </template>
        </gl-sprintf>
      </template>

      <template #actions>
        <reports-export
          v-if="hasAtLeastOneExportAvailable"
          :compliance-status-report-export-path="complianceStatusReportExportPath"
          :project-frameworks-csv-export-path="projectFrameworksCsvExportPath"
          :merge-commits-csv-export-path="mergeCommitsCsvExportPath"
          :compliance-violations-csv-export-path="complianceViolationsCsvExportPath"
          :violations-csv-export-path="violationsCsvExportPath"
          :adherences-csv-export-path="adherencesCsvExportPath"
          :frameworks-csv-export-path="frameworksCsvExportPath"
        />
        <gl-popover v-if="!isTopLevelGroup" :target="() => $refs.newFrameworkButton">
          <gl-sprintf
            v-if="canAccessRootAncestorComplianceCenter"
            :message="$options.i18n.newFrameworkButtonMessage"
          >
            <template #link>
              <gl-link :href="rootAncestor.complianceCenterPath">{{ rootAncestor.name }}</gl-link>
            </template>
          </gl-sprintf>
          <gl-sprintf v-else :message="$options.i18n.tooltipMessageNoAccess">
            <template #strong>
              <strong>{{ rootAncestor.name }}</strong>
            </template>
          </gl-sprintf>
        </gl-popover>
        <span v-if="isGroup" ref="newFrameworkButton">
          <gl-button
            v-if="canAdminComplianceFramework"
            variant="confirm"
            category="secondary"
            :disabled="!isTopLevelGroup"
            @click="newFramework"
            >{{ $options.i18n.newFramework }}</gl-button
          >
        </span>
      </template>
    </page-heading>

    <gl-tabs :value="tabIndex" content-class="gl-p-0" lazy>
      <gl-tab
        v-for="tab in tabs"
        :key="tab.target"
        :title="tab.title"
        :title-link-attributes="tab.titleAttributes"
        :data-testid="tab.contentTestId"
        @click="goTo(tab.target)"
      />
    </gl-tabs>
    <router-view />
  </div>
</template>
