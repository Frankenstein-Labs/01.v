<script>
import { GlButton, GlIcon } from '@gitlab/ui';

export default {
  name: 'StartUltimateTrialCard',
  components: {
    GlButton,
    GlIcon,
  },
  inject: {
    startTrialPath: {
      default: '',
    },
  },
};
</script>

<template>
  <div class="gl-border gl-flex-1 gl-rounded-xl gl-bg-subtle gl-p-5 gl-text-subtle">
    <h3 class="gl-heading-3 gl-mb-3">
      {{ s__('BillingPlans|Get the most out of GitLab with Ultimate') }}
    </h3>

    <p>
      {{
        s__(
          'BillingPlans|Start an Ultimate trial with GitLab Duo Agent Platform to try the complete set of features from GitLab.',
        )
      }}
    </p>

    <ul class="gl-flex gl-list-none gl-flex-col gl-gap-3 gl-pl-0 gl-text-default">
      <li>
        <gl-icon name="check" variant="info" class="gl-mr-2" />
        <span>{{ s__('BillingPlans|GitLab Duo Agent Platform') }}</span>
      </li>

      <li>
        <gl-icon name="check" variant="info" class="gl-mr-2" />
        <span>{{ s__('BillingPlans|Advanced CI/CD') }}</span>
      </li>

      <li>
        <gl-icon name="check" variant="info" class="gl-mr-2" />
        <span>{{ s__('BillingPlans|No credit card required') }}</span>
      </li>
    </ul>

    <gl-button
      category="secondary"
      data-event-tracking="click_start_trial_cta_group_billing"
      :href="startTrialPath"
      >{{ s__('BillingPlans|Start free trial') }}</gl-button
    >
  </div>
</template>
