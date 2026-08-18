<script>
import { GlButton } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'CurrentPlanHeader',
  components: {
    GlButton,
  },
  props: {
    seatsInUse: {
      type: Number,
      required: true,
    },
    trialActive: {
      type: Boolean,
      required: true,
    },
    manageSeatsPath: {
      type: String,
      required: false,
      default: '',
    },
    totalSeats: {
      type: Number,
      required: false,
      default: 0,
    },
    totalGroups: {
      type: Number,
      required: false,
      default: 0,
    },
    totalProjects: {
      type: Number,
      required: false,
      default: 0,
    },
    trialEndsOn: {
      type: String,
      required: false,
      default: '',
    },
    isSaas: {
      type: Boolean,
      required: true,
    },
  },
  computed: {
    header() {
      const planName = this.trialActive
        ? s__('BillingPlans|a trial of Ultimate')
        : s__('BillingPlans|GitLab Free');

      const platform = this.isSaas ? s__('BillingPlans|group') : s__('BillingPlans|instance');
      return sprintf(s__('BillingPlans|Your %{platform} is on %{planName}'), {
        planName,
        platform,
      });
    },
    subscriptionInfo() {
      if (this.isSaas) {
        return [{ value: this.seats, description: s__('BillingPlans|Seats in use') }];
      }

      return [
        { value: this.seats, description: s__('BillingPlans|users') },
        { value: this.totalGroups, description: s__('BillingPlans|groups') },
        { value: this.totalProjects, description: s__('BillingPlans|projects') },
      ];
    },
    seats() {
      if (this.trialActive || !this.isSaas) {
        return this.seatsInUse;
      }

      return `${this.seatsInUse}/${this.totalSeats || __('Unlimited')}`;
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-flex gl-flex-1 gl-flex-col gl-justify-between gl-rounded-t-lg gl-bg-default gl-p-6 md:gl-rounded-l-lg md:gl-rounded-r-none"
  >
    <div>
      <h3 class="gl-heading-3-fixed gl-mb-3 gl-text-default">
        {{ header }}
      </h3>

      <div v-if="trialActive" class="gl-text-sm gl-text-subtle">
        {{ s__('BillingPlans|This trial ends on') }}
        <span class="gl-font-bold">{{ trialEndsOn }}</span>
      </div>

      <div class="gl-mt-5 gl-text-lg">
        <div v-for="(item, i) in subscriptionInfo" :key="i">
          <span
            class="gl-mr-3 gl-text-size-h1 gl-font-bold"
            :data-testid="`subscription-${item.description.replace(/\s/g, '-').toLowerCase()}`"
          >
            {{ item.value }}
          </span>
          <span class="gl-text-subtle">{{ item.description }}</span>
        </div>
      </div>
    </div>

    <div v-if="isSaas" class="gl-mt-5 gl-flex-row">
      <gl-button
        category="secondary"
        data-track-action="click_button"
        data-track-label="manage_seats"
        :href="manageSeatsPath"
        >{{ s__('BillingPlans|Manage seats') }}</gl-button
      >
    </div>
  </div>
</template>
