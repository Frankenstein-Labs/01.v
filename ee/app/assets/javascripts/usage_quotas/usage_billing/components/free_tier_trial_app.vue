<script>
import { GlAlert, GlSprintf, GlLink, GlTab, GlTabs } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { helpPagePath } from '~/helpers/help_page_helper';
import { InternalEvents } from '~/tracking';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { LONG_DATE_FORMAT_WITH_TZ } from '~/vue_shared/constants';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import getTrialUsageQuery from '../graphql/get_trial_usage.query.graphql';
import UpgradeToPremiumCard from './upgrade_to_premium_card.vue';
import FreeTierPurchaseCommitmentCard from './free_tier_purchase_commitment_card.vue';
import TrialUsageByUserTab from './trial_usage_by_user_tab.vue';

export default {
  name: 'FreeTierTrialApp',
  components: {
    GlAlert,
    GlSprintf,
    GlLink,
    GlTab,
    GlTabs,
    PageHeading,
    HumanTimeframe,
    UpgradeToPremiumCard,
    FreeTierPurchaseCommitmentCard,
    TrialUsageByUserTab,
  },
  mixins: [InternalEvents.mixin()],
  apollo: {
    trialUsageData: {
      query: getTrialUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
        };
      },
      update({ trialUsage }) {
        return trialUsage ?? {};
      },
      error(error) {
        logError(error);
        captureException(error);
        this.isError = true;
      },
    },
  },
  inject: {
    namespacePath: { default: '' },
  },
  data() {
    return {
      isError: false,
      trialUsageData: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.trialUsageData.loading;
    },
    inFreeTierTrial() {
      return Boolean(this.trialUsageData?.activeTrial);
    },
    fromDate() {
      return this.trialUsageData?.activeTrial?.startDate;
    },
    tillDate() {
      return this.trialUsageData?.activeTrial?.endDate;
    },
    showDateRange() {
      return Boolean(this.fromDate && this.tillDate);
    },
    shouldDisplayUserData() {
      return gon.display_gitlab_credits_user_data;
    },
  },
  mounted() {
    this.trackEvent('view_usage_billing_pageload');
  },
  LONG_DATE_FORMAT_WITH_TZ,
  displayUserDataHelpPath: helpPagePath('user/group/manage', {
    anchor: 'display-gitlab-credits-user-data',
  }),
};
</script>

<template>
  <section>
    <page-heading class="gl-mb-6">
      <template #heading>
        <span data-testid="usage-billing-title">
          {{ s__('UsageBilling|GitLab Credits') }}
          <span v-if="inFreeTierTrial" class="gl-text-sm gl-text-subtle">
            {{ s__('UsageBilling|(Trial)') }}
          </span>
        </span>
      </template>
      <template #description>
        <div v-if="showDateRange" class="gl-mb-2 gl-text-lg gl-text-default">
          <span class="gl-font-bold">
            {{ s__('UsageBilling|Trial period:') }}
          </span>
          <human-timeframe :from="fromDate" :till="tillDate" />
        </div>
      </template>
    </page-heading>

    <gl-alert v-if="isError" variant="danger" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <template v-else>
      <section
        v-if="isLoading"
        class="gl-my-5 gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row"
        data-testid="trial-loading-state"
      >
        <div class="gl-flex-1">
          <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-12 gl-w-1/2 gl-rounded-base"></div>
          <div class="gl-w-24 gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
        </div>
        <div class="gl-flex-1">
          <div class="gl-animate-skeleton-loader gl-mb-3 gl-h-12 gl-w-1/2 gl-rounded-base"></div>
          <div class="gl-w-24 gl-animate-skeleton-loader gl-h-5 gl-rounded-base"></div>
        </div>
      </section>

      <section
        v-else
        class="gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row"
        data-testid="trial-usage-cards-row"
      >
        <free-tier-purchase-commitment-card />
        <upgrade-to-premium-card />
      </section>

      <gl-tabs v-if="!isLoading" class="gl-mt-5" lazy>
        <gl-tab :title="s__('UsageBilling|Usage by user')">
          <trial-usage-by-user-tab v-if="shouldDisplayUserData" />
          <div v-else data-testid="user-data-disabled-alert" class="gl-mt-4 gl-text-subtle">
            <gl-sprintf
              :message="
                s__(
                  'UsageBilling|Displaying user data is disabled. %{linkStart}Learn more%{linkEnd}.',
                )
              "
            >
              <template #link="{ content }">
                <gl-link :href="$options.displayUserDataHelpPath">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </div>
        </gl-tab>
      </gl-tabs>
    </template>
  </section>
</template>
