<script>
import { GlCard, GlLink, GlSprintf, GlBadge, GlPopover } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { formatNumber } from '../utils';

export default {
  name: 'CurrentOverageUsageCard',
  components: {
    GlCard,
    GlLink,
    GlSprintf,
    GlBadge,
    GlPopover,
  },
  props: {
    overageCreditsUsed: {
      type: Number,
      required: true,
    },
    overageIsAllowed: {
      type: Boolean,
      required: true,
    },
    monthlyWaiverCreditsUsed: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  methods: {
    formatNumber,
  },
  pricingLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-flex-1" body-class="gl-p-4">
    <template #header>
      <div class="gl-flex gl-flex-col gl-justify-between @xl:gl-flex-row">
        <h2 class="gl-heading-scale-500 gl-mb-0">
          {{ s__('UsageBilling|On Demand') }}
        </h2>
        <template v-if="overageIsAllowed">
          <gl-badge
            id="onDemandEnabledPopover"
            class="gl-place-self-start"
            variant="success"
            icon="check-circle"
            >{{ __('Active') }}</gl-badge
          >
          <gl-popover
            target="onDemandEnabledPopover"
            title="On-Demand billing is active"
            triggers="hover"
          >
            <gl-sprintf
              :message="
                s__(
                  'UsageBilling|You will be billed for this usage at the end of the month. Learn more about %{pricingLinkStart}GitLab Credit pricing%{pricingLinkEnd}.',
                )
              "
            >
              <template #pricingLink="{ content }">
                <gl-link :href="$options.pricingLink">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </gl-popover>
        </template>
        <template v-else>
          <gl-badge
            id="onDemandDisabledPopover"
            class="gl-place-self-start"
            variant="neutral"
            icon="information-o"
            >{{ __('Inactive') }}</gl-badge
          >
          <gl-popover
            target="onDemandDisabledPopover"
            title="On-Demand billing is not active"
            triggers="hover"
          >
            <gl-sprintf
              :message="
                s__(
                  'UsageBilling|You won\'t be billed for this usage until you accept the On-Demand billing terms. Learn more about %{pricingLinkStart}GitLab Credit pricing%{pricingLinkEnd}.',
                )
              "
            >
              <template #pricingLink="{ content }">
                <gl-link :href="$options.pricingLink">{{ content }}</gl-link>
              </template>
            </gl-sprintf>
          </gl-popover>
        </template>
      </div>
    </template>
    <template #default>
      <div class="gl-mb-4 gl-text-sm gl-text-subtle">
        {{ s__('UsageBilling|Credits used this month') }}
      </div>

      <div class="gl-mb-3">
        <span class="gl-heading-scale-600 gl-font-bold" data-testid="overage-credits-used">
          {{ formatNumber(overageCreditsUsed) }}
        </span>
      </div>

      <p class="gl-border-t gl-mb-0 gl-mt-auto gl-pt-3 gl-text-sm gl-text-subtle">
        {{
          s__(
            'UsageBilling|Credits consumed beyond your users included credits, charged at standard on-demand rates.',
          )
        }}
        <template v-if="!overageIsAllowed">
          {{
            s__(
              "UsageBilling|You won't be billed for this usage until you accept the on-demand billing terms.",
            )
          }}
        </template>
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|Learn more about %{helpLinkStart}GitLab Credit pricing%{helpLinkEnd}.',
            )
          "
        >
          <template #helpLink="{ content }">
            <gl-link :href="$options.pricingLink">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>

      <div
        v-if="monthlyWaiverCreditsUsed"
        class="gl-border-t gl-flex gl-flex-row gl-justify-between gl-pt-3 gl-text-sm gl-text-subtle"
      >
        <span>{{ s__('UsageBilling|Monthly Waiver credits used this period') }}</span>
        <span data-testid="monthly-waiver-credits-used">
          {{ formatNumber(monthlyWaiverCreditsUsed) }}
        </span>
      </div>
    </template>
  </gl-card>
</template>
