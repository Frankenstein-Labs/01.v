<script>
import { GlSkeletonLoader } from '@gitlab/ui';

export default {
  name: 'CodeSuggestionsUsageLoader',
  components: {
    GlSkeletonLoader,
  },
};
</script>

<template>
  <section>
    <div class="gl-mt-5">
      <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
        <gl-skeleton-loader :height="10">
          <circle cx="4" cy="6" r="2" />
          <rect width="100" height="4" x="8" y="4" rx="2" />
          <rect width="10%" height="100%" x="90%" y="0" rx="1" />
        </gl-skeleton-loader>
      </div>
    </div>

    <div class="gl-mt-5 gl-grid gl-gap-5 @md/panel:gl-grid-cols-2">
      <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
        <gl-skeleton-loader :height="64">
          <rect width="140" height="30" x="5" y="0" rx="4" />
          <rect width="240" height="10" x="5" y="40" rx="4" />
          <rect width="340" height="10" x="5" y="54" rx="4" />
        </gl-skeleton-loader>
      </div>

      <div class="gl-border gl-rounded-base gl-bg-default gl-p-5">
        <gl-skeleton-loader :height="64">
          <rect width="240" height="10" x="5" y="0" rx="4" />
          <rect width="340" height="10" x="5" y="14" rx="4" />
          <rect width="220" height="8" x="5" y="40" rx="4" />
          <rect width="220" height="8" x="5" y="54" rx="4" />
        </gl-skeleton-loader>
      </div>
    </div>
  </section>
</template>
