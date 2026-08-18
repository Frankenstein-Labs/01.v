<script>
import { GlLink, GlTooltipDirective } from '@gitlab/ui';
import { keyBy } from 'lodash-es';
import {
  SEVERITY_LEVEL_CRITICAL,
  SEVERITY_LEVEL_HIGH,
  SEVERITY_LEVEL_UNKNOWN,
  SEVERITY_LEVEL_MEDIUM,
  SEVERITY_LEVEL_LOW,
  SEVERITY_LEVELS,
  SEVERITY_GROUP_F,
  SEVERITY_GROUP_D,
  SEVERITY_GROUP_C,
  SEVERITY_GROUP_B,
  SEVERITY_GROUP_A,
  SEVERITY_GROUPS,
  EXPORT_ERROR_MESSAGE_CHART_LOADING,
} from 'ee/security_dashboard/constants';
import { Accordion, AccordionItem } from 'ee/security_dashboard/components/shared/accordion';
import { s__, n__, sprintf } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { limitVulnerabilityGradeProjects, PdfExportError } from 'ee/security_dashboard/helpers';
import SecurityDashboardCard from './security_dashboard_card.vue';

const SEVERITY_LEVELS_ORDERED_BY_SEVERITY = [
  SEVERITY_LEVEL_CRITICAL,
  SEVERITY_LEVEL_HIGH,
  SEVERITY_LEVEL_UNKNOWN,
  SEVERITY_LEVEL_MEDIUM,
  SEVERITY_LEVEL_LOW,
];

export default {
  css: {
    severityGroups: {
      [SEVERITY_GROUP_F]: 'gl-text-red-800',
      [SEVERITY_GROUP_D]: 'gl-text-red-700',
      [SEVERITY_GROUP_C]: 'gl-text-orange-600',
      [SEVERITY_GROUP_B]: 'gl-text-orange-400',
      [SEVERITY_GROUP_A]: 'gl-text-success',
    },
    severityLevels: {
      [SEVERITY_LEVEL_CRITICAL]: 'gl-text-red-800',
      [SEVERITY_LEVEL_HIGH]: 'gl-text-red-700',
      [SEVERITY_LEVEL_UNKNOWN]: 'gl-text-gray-300',
      [SEVERITY_LEVEL_MEDIUM]: 'gl-text-orange-600',
      [SEVERITY_LEVEL_LOW]: 'gl-text-orange-500',
    },
  },
  accordionItemsContentMaxHeight: '445px',
  components: { SecurityDashboardCard, Accordion, AccordionItem, GlLink, HelpIcon },
  directives: {
    'gl-tooltip': GlTooltipDirective,
  },
  inject: ['groupFullPath'],
  props: {
    helpPagePath: {
      type: String,
      required: false,
      default: '',
    },
    query: {
      type: Object,
      required: true,
    },
  },
  emits: ['chart-report-data-registered'],
  data() {
    return {
      vulnerabilityGrades: {},
      errorLoadingVulnerabilitiesGrades: false,
      expandedGrade: SEVERITY_GROUP_F,
      limitedVulnerabilityGrades: [],
    };
  },
  apollo: {
    vulnerabilityGrades: {
      query() {
        return this.query;
      },
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      update(results) {
        const { vulnerabilityGrades } = this.groupFullPath
          ? results.group
          : results.instanceSecurityDashboard;

        this.limitedVulnerabilityGrades = limitVulnerabilityGradeProjects(vulnerabilityGrades);

        // This will convert the results array into an object where the key is the grade property:
        // {
        //    A: { grade: 'A', count: 1, projects: { nodes: [ ... ] },
        //    B: { grade: 'B', count: 2, projects: { nodes: [ ... ] }
        // }
        return keyBy(vulnerabilityGrades, 'grade');
      },
      error() {
        this.errorLoadingVulnerabilitiesGrades = true;
      },
    },
  },
  computed: {
    isLoadingGrades() {
      return this.$apollo.queries.vulnerabilityGrades.loading;
    },
    severityGroups() {
      return SEVERITY_GROUPS.map((group) => ({
        ...group,
        count: this.vulnerabilityGrades[group.type]?.count || 0,
        projects: this.findProjectsForGroup(group),
      }));
    },
  },
  mounted() {
    this.$emit('chart-report-data-registered', this.getChartReportData);
  },
  methods: {
    findProjectsForGroup(group) {
      if (!this.vulnerabilityGrades[group.type]) {
        return [];
      }

      return this.vulnerabilityGrades[group.type].projects.nodes.map((project) => ({
        ...project,
        mostSevereVulnerability: this.findMostSevereVulnerabilityForGroup(project, group),
      }));
    },
    findMostSevereVulnerabilityForGroup(project, group) {
      const mostSevereVulnerability = {};

      SEVERITY_LEVELS_ORDERED_BY_SEVERITY.some((level) => {
        if (!group.severityLevels.includes(level)) {
          return false;
        }

        const hasVulnerabilityForThisLevel = project.vulnerabilitySeveritiesCount?.[level] > 0;

        if (hasVulnerabilityForThisLevel) {
          mostSevereVulnerability.level = level;
          mostSevereVulnerability.count = project.vulnerabilitySeveritiesCount[level];
        }

        return hasVulnerabilityForThisLevel;
      });

      return mostSevereVulnerability;
    },
    shouldAccordionItemBeDisabled({ projects }) {
      return projects?.length < 1;
    },
    cssForSeverityGroup({ type }) {
      return this.$options.css.severityGroups[type];
    },
    cssForMostSevereVulnerability({ level }) {
      return this.$options.css.severityLevels[level] || [];
    },
    severityText(severityLevel) {
      return SEVERITY_LEVELS[severityLevel];
    },
    getProjectCountString({ count, projects }) {
      // The backend only returns the first 100 projects, so if the project count is greater than
      // the projects array length, we'll show "100+ projects". Note that n__ only works with
      // numbers, so we can't pass it a string like "100+", which is why we need the ternary to
      // use a different string for "100+ projects". This is temporary code until this backend issue
      // is complete, and we can show the actual counts and page through the projects:
      // https://gitlab.com/gitlab-org/gitlab/-/issues/350110
      return count > projects.length
        ? sprintf(s__('SecurityReports|%{count}+ projects'), { count: projects.length })
        : n__('%d project', '%d projects', count);
    },
    onAccordionInput(grade) {
      this.expandedGrade = grade;
    },
    getChartReportData() {
      if (this.isLoadingGrades) {
        throw new PdfExportError(EXPORT_ERROR_MESSAGE_CHART_LOADING);
      }

      return {
        vulnerability_grades: this.limitedVulnerabilityGrades,
        expanded_grade: this.expandedGrade,
      };
    },
  },
};
</script>

<template>
  <security-dashboard-card :is-loading="isLoadingGrades">
    <template #title>
      {{ __('Project security status') }}
      <gl-link
        v-if="helpPagePath"
        :href="helpPagePath"
        :aria-label="__('Project security status help page')"
        target="_blank"
        ><help-icon
      /></gl-link>
    </template>
    <template v-if="!isLoadingGrades" #help-text>
      {{ __('Projects are graded based on the highest severity vulnerability present') }}
    </template>

    <accordion
      class="gl-flex gl-grow gl-border-t-1 gl-border-t-default gl-px-5 gl-border-t-solid"
      :list-classes="['gl-flex', 'gl-grow']"
    >
      <template #default="{ accordionId }">
        <accordion-item
          v-for="severityGroup in severityGroups"
          :ref="`accordionItem${severityGroup.type}`"
          :key="severityGroup.type"
          :data-testid="`severity-accordion-item-${severityGroup.type}`"
          :accordion-id="accordionId"
          :disabled="shouldAccordionItemBeDisabled(severityGroup)"
          :max-height="$options.accordionItemsContentMaxHeight"
          class="gl-flex gl-grow gl-flex-col gl-justify-center"
          @input="onAccordionInput(severityGroup.type)"
        >
          <template #title="{ isExpanded, isDisabled }">
            <h5
              class="gl-m-0 gl-flex gl-items-center gl-p-0 gl-font-normal"
              data-testid="vulnerability-severity-groups"
            >
              <span
                v-gl-tooltip
                :title="severityGroup.description"
                class="gl-mr-5 gl-text-lg gl-font-bold"
                :class="cssForSeverityGroup(severityGroup)"
              >
                {{ severityGroup.type }}
              </span>
              <span :class="{ 'gl-font-bold': isExpanded, 'gl-text-subtle': isDisabled }">
                {{ getProjectCountString(severityGroup) }}
              </span>
            </h5>
          </template>
          <template #sub-title>
            <p class="gl-m-0 gl-ml-7 gl-pb-2 gl-text-subtle">{{ severityGroup.warning }}</p>
          </template>
          <div class="gl-ml-7 gl-pb-3">
            <ul class="list-unstyled gl-py-2">
              <li v-for="project in severityGroup.projects" :key="project.id" class="gl-py-3">
                <gl-link
                  target="_blank"
                  :href="project.securityDashboardPath"
                  data-testid="project-name-text"
                  >{{ project.nameWithNamespace }}</gl-link
                >
                <span
                  v-if="project.mostSevereVulnerability"
                  ref="mostSevereCount"
                  class="gl-block gl-lowercase"
                  :class="cssForMostSevereVulnerability(project.mostSevereVulnerability)"
                  >{{ project.mostSevereVulnerability.count }}
                  {{ severityText(project.mostSevereVulnerability.level) }}
                </span>
              </li>
            </ul>
          </div>
        </accordion-item>
      </template>
    </accordion>
  </security-dashboard-card>
</template>
