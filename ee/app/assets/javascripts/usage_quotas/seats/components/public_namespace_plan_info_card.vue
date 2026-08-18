<script>
import { GlButton, GlSprintf } from '@gitlab/ui';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import Tracking from '~/tracking';
import getGitlabSubscriptionQuery from 'ee/usage_quotas/seats/graphql/get_gitlab_subscription.query.graphql';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import { EXPLORE_PAID_PLANS_CLICKED } from 'ee/usage_quotas/seats/constants';

export default {
  name: 'PublicNamespacePlanInfoCard',
  components: {
    GlButton,
    GlSprintf,
    UsageStatistics,
  },
  mixins: [Tracking.mixin()],
  inject: ['explorePlansPath', 'namespaceId'],
  data() {
    return {
      plan: {},
    };
  },
  apollo: {
    plan: {
      query: getGitlabSubscriptionQuery,
      variables() {
        return {
          namespaceId: this.namespaceId,
        };
      },
      update: (data) => ({
        code: data?.subscription?.plan.code,
        name: data?.subscription?.plan.name,
      }),
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
    planName() {
      return this.plan.name || capitalizeFirstCharacter(this.plan.code);
    },
  },
  methods: {
    handleExplorePlans() {
      this.track('click_button', { label: EXPLORE_PAID_PLANS_CLICKED });
    },
  },
};
</script>
<template>
  <div class="gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-default gl-p-6">
    <usage-statistics>
      <template #actions>
        <gl-button
          v-if="!isLoading"
          :href="explorePlansPath"
          category="primary"
          target="_blank"
          size="small"
          variant="confirm"
          data-testid="explore-plans"
          @click="handleExplorePlans"
        >
          {{ s__('Billing|Explore paid plans') }}
        </gl-button>
      </template>
      <template #description>
        <p class="gl-text-size-h2 gl-font-bold" data-testid="title">
          <gl-sprintf :message="s__('Billing|%{plan} Plan')">
            <template #plan>
              {{ planName }}
            </template>
          </gl-sprintf>
        </p>
        <p data-testid="free-plan-info">
          {{ s__('Billing|You can upgrade to a paid tier to get access to more features.') }}
        </p>
      </template>
    </usage-statistics>
  </div>
</template>
