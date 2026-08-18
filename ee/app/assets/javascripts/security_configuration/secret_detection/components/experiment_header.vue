<script>
import { GlExperimentBadge, GlSprintf } from '@gitlab/ui';
import PromoPageLink from '~/vue_shared/components/promo_page_link/promo_page_link.vue';
import { s__ } from '~/locale';

export default {
  name: 'ExperimentHeader',
  components: {
    GlExperimentBadge,
    PromoPageLink,
    GlSprintf,
  },
  i18n: {
    experimentBadgeText: s__(
      'SecurityExclusions|This feature is subject to the %{linkStart}GitLab Testing Agreement%{linkEnd}.',
    ),
  },
  // eslint-disable-next-line @gitlab/no-hardcoded-urls -- path for PromoPageLink component
  testingAgreementPath: '/handbook/legal/testing-agreement/',
};
</script>
<template>
  <div class="gl-border gl-mb-5 gl-rounded-base gl-border-default gl-bg-subtle gl-p-4">
    <gl-experiment-badge />
    <gl-sprintf :message="$options.i18n.experimentBadgeText">
      <template #link="{ content }">
        <promo-page-link :path="$options.testingAgreementPath">
          {{ content }}
        </promo-page-link>
      </template>
    </gl-sprintf>
  </div>
</template>
