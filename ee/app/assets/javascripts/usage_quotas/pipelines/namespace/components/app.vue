<script>
import {
  GlAlert,
  GlButton,
  GlLoadingIcon,
  GlFormGroup,
  GlCollapsibleListbox,
  GlModalDirective,
  GlSprintf,
} from '@gitlab/ui';
import { getSubscriptionPermissionsData } from 'ee/fulfillment/shared_queries/subscription_actions_reason.customer.query.graphql';
import { getMonthNames, formatIso8601Date } from '~/lib/utils/datetime_utility';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { pushEECproductAddToCartEvent } from 'ee/google_tag_manager';
import { LIMITED_ACCESS_KEYS } from 'ee/usage_quotas/components/constants';
import { logError } from '~/lib/logger';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { USAGE_BY_MONTH_HEADER, USAGE_BY_PROJECT_HEADER } from 'ee/usage_quotas/constants';
import LimitedAccessModal from 'ee/usage_quotas/components/limited_access_modal.vue';
import getNamespaceCiMinutesUsage from '../graphql/queries/namespace_ci_minutes_usage.query.graphql';
import getProjectsCiMinutesUsage from '../graphql/queries/projects_ci_minutes_usage.query.graphql';
import { ERROR_MESSAGE, LABEL_BUY_ADDITIONAL_MINUTES } from '../constants';
import { groupUsageDataByYear } from '../utils';
import ProjectList from './project_list.vue';
import MinutesUsagePerMonth from './minutes_usage_per_month.vue';
import MinutesUsagePerProject from './minutes_usage_per_project.vue';
import AdditionalUnitsUsageSummary from './cards/additional_units_usage_summary.vue';
import MonthlyUnitsUsageSummary from './cards/monthly_units_usage_summary.vue';

export default {
  name: 'PipelineUsageApp',
  components: {
    HelpPageLink,
    GlAlert,
    GlButton,
    GlCollapsibleListbox,
    GlLoadingIcon,
    GlFormGroup,
    GlSprintf,
    LimitedAccessModal,
    ProjectList,
    MinutesUsagePerProject,
    MinutesUsagePerMonth,
    AdditionalUnitsUsageSummary,
    MonthlyUnitsUsageSummary,
  },
  directives: {
    GlModalDirective,
  },
  inject: [
    'pageSize',
    'namespaceId',
    'namespaceActualPlanName',
    'userNamespace',
    'ciMinutesAnyProjectEnabled',
    'ciMinutesDisplayMinutesAvailableData',
    'ciMinutesLastResetDate',
    'ciMinutesMonthlyMinutesLimit',
    'ciMinutesMonthlyMinutesUsed',
    'ciMinutesMonthlyMinutesUsedPercentage',
    'ciMinutesPurchasedMinutesLimit',
    'ciMinutesPurchasedMinutesUsed',
    'ciMinutesPurchasedMinutesUsedPercentage',
    'buyAdditionalMinutesPath',
    'buyAdditionalMinutesTarget',
  ],
  data() {
    const lastResetDate = new Date(this.ciMinutesLastResetDate);
    const year = lastResetDate.getUTCFullYear();
    const month = lastResetDate.getUTCMonth();

    return {
      error: '',
      ciMinutesUsage: [],
      projectsCiMinutesUsage: null,
      selectedYear: year,
      selectedMonth: month, // 0-based month index
      subscriptionPermissions: null,
      isLimitedAccessModalShown: false,
    };
  },
  apollo: {
    ciMinutesUsage: {
      query() {
        return getNamespaceCiMinutesUsage;
      },
      variables() {
        return {
          namespaceId: this.userNamespace
            ? null
            : convertToGraphQLId(TYPENAME_GROUP, this.namespaceId),
        };
      },
      update(res) {
        return res?.ciMinutesUsage?.nodes;
      },
      error(error) {
        this.error = ERROR_MESSAGE;
        captureException(error);
        logError('PipelineUsageApp: error fetching ciMinutesUsage query.', error);
      },
    },
    projectsCiMinutesUsage: {
      query() {
        return getProjectsCiMinutesUsage;
      },
      variables() {
        return {
          namespaceId: this.userNamespace
            ? null
            : convertToGraphQLId(TYPENAME_GROUP, this.namespaceId),
          first: this.pageSize,
          date: this.selectedDateInIso8601,
        };
      },
      update(res) {
        return res?.ciMinutesProjectMonthlyUsage;
      },
      error(error) {
        this.error = ERROR_MESSAGE;
        captureException(error);
        logError('PipelineUsageApp: error fetching projectsCiMinutesUsage query.', error);
      },
    },
    subscriptionPermissions: {
      query: getSubscriptionPermissionsData,
      client: 'customersDotClient',
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update: (data) => ({
        ...data.subscription,
        reason: data.userActionAccess?.limitedAccessReason,
      }),
      error(error) {
        captureException(error);
        logError('PipelineUsageApp: error fetching subscriptionPermissions query.', error);
      },
    },
  },
  computed: {
    selectedDateInIso8601() {
      return formatIso8601Date(this.selectedYear, this.selectedMonth, 1);
    },
    projects() {
      return this.projectsCiMinutesUsage?.nodes ?? [];
    },
    projectsPageInfo() {
      return this.projectsCiMinutesUsage?.pageInfo ?? {};
    },
    shouldShowBuyAdditionalMinutes() {
      return (
        this.buyAdditionalMinutesPath &&
        this.buyAdditionalMinutesTarget &&
        !this.$apollo.queries.subscriptionPermissions.loading
      );
    },
    isLoadingYearUsageData() {
      return this.$apollo.queries.ciMinutesUsage.loading;
    },
    isLoadingMonthProjectUsageData() {
      return this.$apollo.queries.projectsCiMinutesUsage.loading;
    },
    shouldShowAdditionalMinutes() {
      return (
        this.ciMinutesDisplayMinutesAvailableData && Number(this.ciMinutesPurchasedMinutesLimit) > 0
      );
    },
    usageDataByYear() {
      return groupUsageDataByYear(this.ciMinutesUsage);
    },
    years() {
      return Object.keys(this.usageDataByYear)
        .map(Number)
        .reverse()
        .map((year) => ({
          text: String(year),
          value: year,
        }));
    },
    months() {
      return getMonthNames().map((month, index) => ({
        text: month,
        value: index,
      }));
    },
    selectedMonthName() {
      return getMonthNames()[this.selectedMonth];
    },
    shouldShowLimitedAccessModal() {
      // NOTE: we're using existing flag for seats `canAddSeats`, to infer
      // whether the additional minutes are expandable.
      const canAddMinutes = this.subscriptionPermissions?.canAddSeats ?? true;

      return !canAddMinutes && LIMITED_ACCESS_KEYS.includes(this.subscriptionPermissions.reason);
    },
    // ref_source tracks navigation context for CDOT conversion attribution
    buyAdditionalMinutesPathWithRefSource() {
      return (
        this.buyAdditionalMinutesPath &&
        mergeUrlParams({ ref_source: 'group_usage_quotas_page' }, this.buyAdditionalMinutesPath)
      );
    },
  },
  methods: {
    clearError() {
      this.error = '';
    },
    fetchMoreProjects(variables) {
      this.$apollo.queries.projectsCiMinutesUsage.fetchMore({
        variables: {
          namespaceId: this.userNamespace
            ? null
            : convertToGraphQLId(TYPENAME_GROUP, this.namespaceId),
          date: this.selectedDateInIso8601,
          ...variables,
        },
        updateQuery(previousResult, { fetchMoreResult }) {
          return fetchMoreResult;
        },
      });
    },
    trackBuyAdditionalMinutesClick() {
      pushEECproductAddToCartEvent();
    },
    showLimitedAccessModal() {
      this.isLimitedAccessModalShown = true;
      this.trackBuyAdditionalMinutesClick();
    },
  },
  LABEL_BUY_ADDITIONAL_MINUTES,
  USAGE_BY_MONTH_HEADER,
  USAGE_BY_PROJECT_HEADER,
};
</script>

<template>
  <div>
    <gl-alert
      v-if="!ciMinutesAnyProjectEnabled"
      variant="info"
      :dismissible="false"
      class="gl-my-2"
      data-testid="instance-runners-disabled-alert"
    >
      {{ s__('UsageQuota|Instance runners are disabled in all projects in this namespace.') }}
    </gl-alert>
    <h2 class="gl-heading-2 gl-my-3" data-testid="overview-subtitle">{{ __('Pipelines') }}</h2>
    <p class="gl-mb-0 gl-text-subtle" data-testid="pipelines-description">
      {{
        s__(
          'UsageQuota|Compute minutes usage displays the hosted runner usage against the total available compute minutes.',
        )
      }}
      <help-page-link href="ci/pipelines/compute_minutes" anchor="compute-usage-calculation">{{
        __('Learn more')
      }}</help-page-link
      >.
    </p>

    <section>
      <div v-if="shouldShowBuyAdditionalMinutes" class="gl-flex gl-justify-end gl-py-3">
        <gl-button
          v-if="!shouldShowLimitedAccessModal"
          :href="buyAdditionalMinutesPathWithRefSource"
          :target="buyAdditionalMinutesTarget"
          :aria-label="$options.LABEL_BUY_ADDITIONAL_MINUTES"
          :data-track-label="namespaceActualPlanName"
          data-testid="buy-compute-minutes"
          data-track-action="click_buy_ci_minutes"
          data-track-property="pipeline_quota_page"
          category="primary"
          variant="confirm"
          @click="trackBuyAdditionalMinutesClick"
        >
          {{ $options.LABEL_BUY_ADDITIONAL_MINUTES }}
        </gl-button>
        <gl-button
          v-else
          v-gl-modal-directive="'limited-access-modal-id'"
          data-testid="buy-compute-minutes"
          category="primary"
          variant="confirm"
          @click="showLimitedAccessModal"
        >
          {{ $options.LABEL_BUY_ADDITIONAL_MINUTES }}
        </gl-button>
        <limited-access-modal
          v-if="shouldShowLimitedAccessModal"
          v-model="isLimitedAccessModalShown"
          :limited-access-reason="subscriptionPermissions.reason"
        />
      </div>
      <div class="gl-grid gl-gap-5 gl-py-4 @md/panel:gl-grid-cols-2">
        <monthly-units-usage-summary
          :monthly-units-used="ciMinutesMonthlyMinutesUsed"
          :monthly-units-limit="ciMinutesMonthlyMinutesLimit"
          :monthly-units-used-percentage="ciMinutesMonthlyMinutesUsedPercentage"
          :last-reset-date="ciMinutesLastResetDate"
          :any-project-enabled="ciMinutesAnyProjectEnabled"
          :display-minutes-available-data="ciMinutesDisplayMinutesAvailableData"
        />
        <additional-units-usage-summary
          v-if="shouldShowAdditionalMinutes"
          :additional-units-used="ciMinutesPurchasedMinutesUsed"
          :additional-units-limit="ciMinutesPurchasedMinutesLimit"
          :additional-units-used-percentage="ciMinutesPurchasedMinutesUsedPercentage"
        />
      </div>
    </section>

    <div class="gl-my-5 gl-flex">
      <gl-form-group :label="s__('UsageQuota|Filter charts by year')">
        <gl-collapsible-listbox
          v-model="selectedYear"
          :items="years"
          :disabled="isLoadingYearUsageData"
          data-testid="minutes-usage-year-dropdown"
        />
      </gl-form-group>
    </div>

    <gl-alert v-if="error" variant="danger" data-testid="error-alert" @dismiss="clearError">
      {{ error }}
    </gl-alert>

    <template v-else>
      <section class="gl-my-5">
        <h3 class="gl-heading-3 gl-mb-3">{{ $options.USAGE_BY_MONTH_HEADER }}</h3>

        <minutes-usage-per-month
          :selected-year="selectedYear"
          :ci-minutes-usage="ciMinutesUsage"
          :is-loading="isLoadingYearUsageData"
        />
      </section>

      <section class="gl-my-5">
        <h3 class="gl-heading-3">{{ $options.USAGE_BY_PROJECT_HEADER }}</h3>

        <div class="gl-my-3 gl-flex">
          <gl-form-group :label="s__('UsageQuota|Filter projects data by month')">
            <gl-collapsible-listbox
              v-model="selectedMonth"
              :items="months"
              :disabled="isLoadingMonthProjectUsageData"
              data-testid="minutes-usage-month-dropdown"
            />
          </gl-form-group>
        </div>

        <gl-loading-icon
          v-if="isLoadingMonthProjectUsageData"
          class="gl-mt-5"
          size="lg"
          data-testid="pipelines-by-project-chart-loading-indicator"
        />

        <template v-else>
          <gl-alert :dismissible="false" class="gl-my-3" data-testid="project-usage-info-alert">
            <gl-sprintf
              :message="
                s__('UsageQuota|The chart and the table below show usage for %{month} %{year}')
              "
            >
              <template #month>{{ selectedMonthName }}</template>
              <template #year>{{ selectedYear }}</template>
            </gl-sprintf>
          </gl-alert>

          <minutes-usage-per-project :projects="projects" />

          <div class="gl-pt-5">
            <project-list
              :projects="projects"
              :page-info="projectsPageInfo"
              @fetch-more="fetchMoreProjects"
            />
          </div>
        </template>
      </section>
    </template>
  </div>
</template>
