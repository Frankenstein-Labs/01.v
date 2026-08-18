<script>
import { GlSprintf, GlLink, GlCard, GlButton } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';

export default {
  name: 'OverageOptInCard',
  components: {
    GlSprintf,
    GlLink,
    GlCard,
    GlButton,
  },
  props: {
    customersUsageDashboardUrl: {
      type: String,
      required: true,
    },
  },
  overageDocsLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-flex-1" body-class="gl-flex gl-flex-col gl-h-full gl-p-4">
    <template #default>
      <h2 class="gl-heading-scale-400 gl-mb-3">
        {{ s__("UsageBilling|Keep your team's GitLab Duo features unblocked") }}
      </h2>
      <p>
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|Accept on-demand billing to keep GitLab Duo features active when monthly GitLab Credits run out. Without these terms, users lose GitLab Duo access after exhausting their included GitLab Credits. Learn about %{linkStart}overage billing%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.overageDocsLink">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <div class="gl-mt-auto">
        <gl-button :href="customersUsageDashboardUrl" variant="confirm">
          {{ s__('UsageBilling|Accept on-demand billing') }}
        </gl-button>
      </div>
    </template>
  </gl-card>
</template>
