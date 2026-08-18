<script>
import { GlButton, GlLink, GlCard, GlSprintf, GlTabs, GlTab } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import UsageByUserTab from './usage_by_user_tab.vue';
import UsageOverviewChart from './usage_overview_chart.vue';

export default {
  name: 'PaidTierTrialPeriodView',
  components: {
    GlButton,
    GlCard,
    GlLink,
    GlSprintf,
    GlTabs,
    GlTab,
    HelpPageLink,
    UsageByUserTab,
    UsageOverviewChart,
  },
  props: {
    customersUsageDashboardUrl: {
      type: String,
      required: true,
    },
    purchaseCreditsUrl: {
      required: false,
      type: String,
      default: null,
    },
    monthStartDate: {
      type: String,
      required: true,
    },
    monthEndDate: {
      type: String,
      required: true,
    },
    commitmentDailyUsage: {
      type: Array,
      required: true,
    },
    waiverDailyUsage: {
      type: Array,
      required: true,
    },
    overageDailyUsage: {
      type: Array,
      required: true,
    },
    paidTierTrialDailyUsage: {
      type: Array,
      required: true,
    },
    usersUsageDailyUsage: {
      type: Array,
      required: true,
    },
  },
  computed: {
    shouldDisplayUserData() {
      return gon.display_gitlab_credits_user_data;
    },
  },
  displayUserDataHelpPath: helpPagePath('user/group/manage', {
    anchor: 'display-gitlab-credits-user-data',
  }),
};
</script>
<template>
  <section class="gl-flex gl-flex-col gl-gap-5">
    <gl-card
      class="gl-w-full"
      body-class="gl-p-4 gl-flex gl-flex-col gl-items-start gl-justify-between gl-gap-5"
      data-testid="paid-tier-trial-header-card"
    >
      <div>
        <h2 class="gl-heading-scale-400 gl-mb-3">
          {{ s__('UsageBilling|Your GitLab evaluation credits are active') }}
        </h2>

        <p class="gl-mb-0">
          <gl-sprintf
            :message="
              s__(
                'UsageBilling|You are currently using temporary evaluation credits to access GitLab Duo features. Your subscription\'s included credits for users will be available after your evaluation ends. If you have access to the %{linkStart}Customers Portal%{linkEnd}, you can view your usage breakdown, remaining balance, and some usage details.',
              )
            "
          >
            <template #link="{ content }">
              <help-page-link
                href="subscriptions/billing_account"
                anchor="sign-in-to-customers-portal"
                target="_blank"
                >{{ content }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </p>
      </div>
      <div class="gl-mt-auto">
        <gl-button
          :href="customersUsageDashboardUrl"
          category="primary"
          variant="confirm"
          icon="external-link"
          target="_blank"
          class="gl-whitespace-nowrap"
        >
          {{ s__('UsageBilling|Go to Customers Portal') }}
        </gl-button>
      </div>
    </gl-card>

    <gl-tabs lazy>
      <gl-tab :title="s__('UsageBilling|Usage overview')">
        <usage-overview-chart
          :month-start-date="monthStartDate"
          :month-end-date="monthEndDate"
          :commitment-daily-usage="commitmentDailyUsage"
          :waiver-daily-usage="waiverDailyUsage"
          :overage-daily-usage="overageDailyUsage"
          :paid-tier-trial-daily-usage="paidTierTrialDailyUsage"
          :users-usage-daily-usage="usersUsageDailyUsage"
        />
      </gl-tab>
      <gl-tab :title="s__('UsageBilling|Usage by user')">
        <usage-by-user-tab v-if="shouldDisplayUserData" />
        <div v-else data-testid="user-data-disabled-alert" class="gl-mt-4 gl-text-subtle">
          <gl-sprintf
            :message="
              s__(
                'UsageBilling|Displaying user data is disabled. %{linkStart}Learn how to enable it%{linkEnd}.',
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

    <section
      class="gl-flex gl-flex-col gl-gap-5 @md/panel:gl-flex-row"
      data-testid="paid-tier-trial-body"
    >
      <gl-card v-if="purchaseCreditsUrl" class="gl-flex-1" body-class="gl-p-4 gl-flex gl-flex-col">
        <template #header>
          <h2 class="gl-heading-scale-400 gl-mb-2">
            {{ s__('UsageBilling|Continue after your evaluation') }}
          </h2>
        </template>
        <template #default>
          <p>
            {{
              s__(
                'UsageBilling|Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
              )
            }}
          </p>

          <div class="gl-mt-auto">
            <gl-link category="tertiary" :href="purchaseCreditsUrl">
              {{ s__('UsageBilling|Purchase monthly commitment') }}
            </gl-link>
          </div>
        </template>
      </gl-card>

      <gl-card class="gl-flex-1" body-class="gl-p-4 gl-flex gl-flex-col">
        <template #header>
          <h2 class="gl-heading-scale-400 gl-mb-2">
            {{ s__('UsageBilling|Learn about GitLab Credits') }}
          </h2>
        </template>
        <template #default>
          <p>
            {{
              s__(
                "UsageBilling|Understand how credits are consumed by different features, explore your billing and commitment options, and learn how to monitor your members' usage.",
              )
            }}
          </p>

          <div class="gl-mt-auto">
            <help-page-link href="subscriptions/gitlab_credits" target="_blank">{{
              s__('UsageBilling|Read the documentation')
            }}</help-page-link>
          </div>
        </template>
      </gl-card>

      <gl-card class="gl-flex-1" body-class="gl-p-4 gl-flex gl-flex-col">
        <template #header>
          <h2 class="gl-heading-scale-400 gl-mb-2">
            {{ s__('UsageBilling|Explore GitLab Duo') }}
          </h2>
        </template>
        <template #default>
          <p>
            {{
              s__(
                'UsageBilling|Try the GitLab Duo Agent Platform and agentic chat to delegate routine tasks like code refactoring, security scans, and research to AI-powered assistants.',
              )
            }}
          </p>

          <div class="gl-mt-auto">
            <help-page-link href="user/gitlab_duo/_index" target="_blank">{{
              s__('UsageBilling|Learn more about GitLab Duo')
            }}</help-page-link>
          </div>
        </template>
      </gl-card>
    </section>
  </section>
</template>
