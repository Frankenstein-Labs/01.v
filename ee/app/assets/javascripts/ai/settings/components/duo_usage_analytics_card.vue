<script>
import { GlButton, GlCard } from '@gitlab/ui';

export default {
  name: 'DuoUsageAnalyticsCard',
  components: {
    GlButton,
    GlCard,
  },
  props: {
    dashboardPath: {
      type: String,
      required: true,
    },
  },
};
</script>
<template>
  <gl-card
    header-class="gl-heading-scale-300"
    footer-class="gl-bg-transparent gl-border-none gl-flex-end"
  >
    <template #header>
      <h3 class="gl-m-0">{{ s__('AiPowered|GitLab Credits dashboard') }}</h3>
    </template>
    <template #default>
      <p class="gl-mb-0 gl-pb-0 gl-text-subtle">
        {{
          s__(
            'AiPowered|Track credit consumption across your users and monitor usage trends. View breakdowns by user to understand how your team utilizes GitLab Duo.',
          )
        }}
      </p>
    </template>
    <template #footer>
      <div>
        <gl-button :to="dashboardPath" category="primary">
          {{ s__('AiPowered|View usage dashboard') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
