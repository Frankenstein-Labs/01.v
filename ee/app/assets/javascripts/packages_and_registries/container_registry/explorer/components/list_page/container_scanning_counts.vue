<script>
import { GlSkeletonLoader, GlSprintf, GlIcon, GlLink } from '@gitlab/ui';
import vulnerabilityCountsQuery from 'ee/packages_and_registries/container_registry/explorer/graphql/queries/get_project_container_scanning.query.graphql';
import { REPORT_TYPE_PRESETS } from 'ee/security_dashboard/components/shared/vulnerability_report/constants';
import {
  VULNERABILITY_STATE_OBJECTS,
  CRITICAL,
  HIGH,
  MEDIUM,
  LOW,
  INFO,
  UNKNOWN,
  SEVERITY_COUNT_LIMIT,
} from 'ee/vulnerabilities/constants';
import { ERROR_POLICY_NONE } from '~/lib/graphql';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

const { detected, confirmed } = VULNERABILITY_STATE_OBJECTS;

export default {
  name: 'ContainerScanningCounts',
  components: { GlSkeletonLoader, GlSprintf, GlIcon, GlLink },
  inject: ['config'],
  data() {
    return {
      project: {},
    };
  },
  i18n: {
    highlights: s__(
      'ciReport|%{criticalStart}critical%{criticalEnd}, %{highStart}high%{highEnd} and %{otherStart}other%{otherEnd} vulnerabilities detected.',
    ),
    latestTagsOnly: s__('ciReport|Runs against latest tags only'),
    viewVulnerabilities: s__('ciReport|View vulnerabilities'),
  },
  computed: {
    isEnabled() {
      return (
        this.project?.containerScanningForRegistry.isEnabled &&
        this.project?.containerScanningForRegistry.isVisible
      );
    },
    isLoadingCounts() {
      return this.$apollo.queries.project.loading;
    },
    vulnerabilityCounts() {
      return this.project?.vulnerabilitySeveritiesCount || {};
    },
    criticalSeverity() {
      return this.formattedCounts(this.vulnerabilityCounts[CRITICAL]);
    },
    highSeverity() {
      return this.formattedCounts(this.vulnerabilityCounts[HIGH]);
    },
    otherSeverity() {
      let totalCounts = 0;

      [MEDIUM, LOW, INFO, UNKNOWN].forEach((severity) => {
        const count = this.vulnerabilityCounts[severity];

        if (count) {
          totalCounts += count;
        }
      });

      return this.formattedCounts(totalCounts);
    },
  },
  apollo: {
    project: {
      query: vulnerabilityCountsQuery,
      errorPolicy: ERROR_POLICY_NONE,
      variables() {
        return {
          fullPath: this.config.projectPath,
          securityConfigurationPath: this.config.securityConfigurationPath,
          reportType: REPORT_TYPE_PRESETS.CONTAINER_REGISTRY,
          state: [detected.searchParamValue, confirmed.searchParamValue],
          capped: true,
        };
      },
      update(data) {
        return data.project;
      },
      error(e) {
        Sentry.captureException(e);
      },
    },
  },
  methods: {
    formattedCounts(count) {
      return count > SEVERITY_COUNT_LIMIT
        ? sprintf(s__('SecurityReports|%{count}+'), { count: SEVERITY_COUNT_LIMIT })
        : count;
    },
  },
};
</script>

<template>
  <div>
    <gl-skeleton-loader v-if="isLoadingCounts" :equal-width-lines="true" :lines="3" />
    <div v-else-if="isEnabled" class="gl-border gl-my-6 gl-p-5 gl-text-base">
      <div data-testid="counts">
        <gl-sprintf :message="$options.i18n.highlights">
          <template #critical="{ content }"
            ><strong class="gl-text-red-800">{{ criticalSeverity }} {{ content }}</strong></template
          >
          <template #high="{ content }"
            ><strong class="gl-text-red-600">{{ highSeverity }} {{ content }}</strong></template
          >
          <template #other="{ content }"
            ><strong>{{ otherSeverity }} {{ content }}</strong></template
          >
        </gl-sprintf>
        <gl-link :href="config.vulnerabilityReportPath">{{
          $options.i18n.viewVulnerabilities
        }}</gl-link>
      </div>

      <div class="gl-pt-2 gl-text-subtle">
        <gl-icon name="information-o" variant="info" />
        {{ $options.i18n.latestTagsOnly }}
      </div>
    </div>
  </div>
</template>
