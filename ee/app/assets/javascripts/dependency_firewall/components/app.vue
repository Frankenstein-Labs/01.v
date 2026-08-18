<script>
import {
  GlCard,
  GlBadge,
  GlAlert,
  GlLink,
  GlSkeletonLoader,
  GlSprintf,
  GlIcon,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { nDaysBefore, toISODateFormat } from '~/lib/utils/datetime_utility';
import DetailLayout from '~/vue_shared/components/detail_layout.vue';
import {
  NAMESPACE_GROUP,
  NAMESPACE_PROJECT,
  ICON_BLOCKED,
  ICON_WARNED,
  ICON_NEUTRAL,
  TIME_WINDOW_OPTIONS,
  DEFAULT_TIME_WINDOW_DAYS,
} from '../constants';
import groupRuleActivityQuery from '../graphql/queries/group_dependency_firewall_rule_activity.query.graphql';
import projectRuleActivityQuery from '../graphql/queries/project_dependency_firewall_rule_activity.query.graphql';
import RuleActivityTable from './rule_activity_table.vue';

export default {
  name: 'DependencyFirewallDashboardApp',
  components: {
    GlCard,
    GlBadge,
    GlAlert,
    GlLink,
    GlSkeletonLoader,
    GlSprintf,
    GlIcon,
    GlCollapsibleListbox,
    DetailLayout,
    RuleActivityTable,
  },
  props: {
    fullPath: {
      type: String,
      required: true,
    },
    namespaceType: {
      type: String,
      required: true,
      validator: (value) => [NAMESPACE_GROUP, NAMESPACE_PROJECT].includes(value),
    },
  },
  apollo: {
    dependencyFirewall: {
      query() {
        return this.namespaceType === NAMESPACE_PROJECT
          ? projectRuleActivityQuery
          : groupRuleActivityQuery;
      },
      // Per-rule counts are window-scoped but cached by rule id, so always refetch.
      fetchPolicy: 'cache-and-network',
      variables() {
        return { fullPath: this.fullPath, from: this.fromDate };
      },
      result({ data }) {
        if (data?.dependencyFirewall) {
          this.hasError = false;
        }
      },
      error() {
        this.hasError = true;
      },
    },
  },
  data() {
    return {
      dependencyFirewall: null,
      hasError: false,
      timeWindowDays: DEFAULT_TIME_WINDOW_DAYS,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.dependencyFirewall.loading;
    },
    fromDate() {
      // Compute in UTC so the day boundary matches the backends
      return toISODateFormat(nDaysBefore(new Date(), this.timeWindowDays - 1, { utc: true }), true);
    },
    timeWindowToggleText() {
      return TIME_WINDOW_OPTIONS.find((option) => option.value === this.timeWindowDays)?.text;
    },
    isProjectLevel() {
      return this.namespaceType === NAMESPACE_PROJECT;
    },
    subtitle() {
      return this.isProjectLevel
        ? s__(
            "DependencyFirewall|Monitor and manage the packages entering your project's supply chain.",
          )
        : s__(
            "DependencyFirewall|Monitor and manage the packages entering your group's supply chain.",
          );
    },
    ruleActivity() {
      return this.dependencyFirewall?.dependencyFirewallRuleActivity || [];
    },
    summary() {
      return {
        blocked: 0,
        warned: 0,
        totalTriggers: 0,
        activeRules: 0,
        blockingRules: 0,
        warningRules: 0,
        ...this.dependencyFirewall?.dependencyFirewallActivitySummary,
      };
    },
    summaryStats() {
      return [
        {
          key: 'blocked',
          label: s__('DependencyFirewall|Blocked'),
          value: this.summary.blocked,
          icon: ICON_BLOCKED,
          iconClass: 'gl-text-danger',
          testid: 'blocked-total',
        },
        {
          key: 'warned',
          label: s__('DependencyFirewall|Warned'),
          value: this.summary.warned,
          icon: ICON_WARNED,
          iconClass: 'gl-text-warning',
          testid: 'warned-total',
        },
        {
          key: 'total',
          label: s__('DependencyFirewall|Total triggers'),
          value: this.summary.totalTriggers,
          icon: ICON_NEUTRAL,
          iconClass: 'gl-text-subtle',
          testid: 'total-triggers',
        },
      ];
    },
  },
  timeWindowOptions: TIME_WINDOW_OPTIONS,
  creditsDocsLink: helpPagePath('subscriptions/gitlab_credits'),
};
</script>

<template>
  <detail-layout :description="subtitle">
    <template #heading>
      <span class="gl-inline-flex gl-items-center gl-gap-3">
        {{ s__('DependencyFirewall|Dependency firewall') }}
        <gl-badge variant="info">{{ __('Beta') }}</gl-badge>
      </span>
    </template>

    <template #actions>
      <span id="dependency-firewall-time-window-label" class="gl-sr-only">
        {{ s__('DependencyFirewall|Time period') }}
      </span>
      <gl-collapsible-listbox
        v-model="timeWindowDays"
        :items="$options.timeWindowOptions"
        :toggle-text="timeWindowToggleText"
        icon="clock"
        toggle-aria-labelled-by="dependency-firewall-time-window-label"
        data-testid="time-window-listbox"
      />
    </template>

    <template #alerts>
      <!-- Copy is duplicated in the shared HAML component (security/dependency_firewall/beta_credits_alert_component.html.haml); keep both in sync (shared msgids). -->
      <gl-alert
        variant="warning"
        :title="s__('DependencyFirewall|Charges may be incurred at the end of beta')"
        :dismissible="false"
        data-testid="ga-billing-alert"
        class="gl-mb-5"
      >
        <gl-sprintf
          :message="
            s__(
              'DependencyFirewall|Dependency Firewall is free during the beta period. Once generally available, it will be a paid feature billed through %{linkStart}GitLab Credits%{linkEnd}. You\'ll need to opt in before anything is charged, and we\'ll give you advance notice ahead of general availability.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.creditsDocsLink" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </gl-alert>

      <gl-alert
        v-if="hasError"
        variant="danger"
        :dismissible="false"
        data-testid="error-alert"
        class="gl-mb-5"
      >
        {{ s__('DependencyFirewall|Failed to load dependency firewall activity.') }}
      </gl-alert>
    </template>

    <div v-if="!hasError" class="gl-mb-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row">
      <gl-card class="gl-grow">
        <template #header>
          <div class="gl-flex gl-items-baseline gl-gap-3">
            <h2 class="gl-m-0 gl-text-base gl-font-bold">
              {{ s__('DependencyFirewall|All activity') }}
            </h2>
            <span
              class="gl-text-base gl-font-normal gl-text-subtle"
              data-testid="time-window-descriptor"
            >
              ({{ timeWindowToggleText }})
            </span>
          </div>
        </template>
        <gl-skeleton-loader v-if="isLoading" />
        <div v-else class="gl-flex gl-gap-6">
          <div v-for="stat in summaryStats" :key="stat.key">
            <div class="gl-flex gl-items-center gl-gap-2">
              <gl-icon :name="stat.icon" :class="stat.iconClass" />
              <span class="gl-text-size-h1 gl-font-bold" :data-testid="stat.testid">{{
                stat.value
              }}</span>
            </div>
            <span class="gl-text-subtle">{{ stat.label }}</span>
          </div>
        </div>
      </gl-card>

      <gl-card class="gl-grow">
        <template #header>
          <h2 class="gl-m-0 gl-text-base gl-font-bold">
            {{ s__('DependencyFirewall|Active policy rules') }}
          </h2>
        </template>
        <gl-skeleton-loader v-if="isLoading" />
        <template v-else>
          <div class="gl-text-size-h1 gl-font-bold" data-testid="active-rules-total">
            {{ summary.activeRules }}
          </div>
          <span class="gl-text-subtle">
            <gl-sprintf
              :message="s__('DependencyFirewall|%{blocking} blocking • %{warning} warning')"
            >
              <template #blocking>{{ summary.blockingRules }}</template>
              <template #warning>{{ summary.warningRules }}</template>
            </gl-sprintf>
          </span>
        </template>
      </gl-card>
    </div>

    <rule-activity-table :items="ruleActivity" :loading="isLoading" />
  </detail-layout>
</template>
