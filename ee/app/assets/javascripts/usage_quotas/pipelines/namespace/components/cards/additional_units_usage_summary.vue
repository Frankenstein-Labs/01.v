<script>
import { s__ } from '~/locale';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'AdditionalUnitsUsageSummary',
  components: { StatisticsCard },
  props: {
    additionalUnitsUsed: {
      type: Number,
      required: true,
    },
    additionalUnitsLimit: {
      type: [Number, String],
      required: true,
    },
    additionalUnitsUsedPercentage: {
      type: Number,
      required: true,
    },
  },
  COMPUTE_MINUTES: s__('UsageQuota|compute minutes'),
  ADDITIONAL_COMPUTE_MINUTES: s__('UsageQuota|Additional compute minutes'),
  HELP_PAGE_LINK: helpPagePath('subscriptions/gitlab_com/compute_minutes'),
};
</script>

<template>
  <statistics-card
    :usage-value="additionalUnitsUsed"
    :total-value="additionalUnitsLimit"
    :total-unit="$options.COMPUTE_MINUTES"
    :description="$options.ADDITIONAL_COMPUTE_MINUTES"
    :percentage="additionalUnitsUsedPercentage"
    :help-link="$options.HELP_PAGE_LINK"
    :help-label="$options.ADDITIONAL_COMPUTE_MINUTES"
    summary-data-testid="additional-compute-minutes"
  />
</template>
