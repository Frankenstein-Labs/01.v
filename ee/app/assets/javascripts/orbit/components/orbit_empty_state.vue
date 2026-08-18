<script>
import { defineComponent } from 'vue';
import { GlBadge, GlLink } from '@gitlab/ui';
import { DOCS_URL } from '~/constants';

export default defineComponent({
  name: 'OrbitEmptyState',
  compatConfig: { MODE: 3 },
  components: {
    GlBadge,
    GlLink,
  },
  learnMorePath: `${DOCS_URL}/orbit/`,
});
</script>

<template>
  <div
    class="orbit-dot-grid-host gl-relative gl-flex gl-min-h-full gl-flex-1 gl-flex-col gl-items-center gl-justify-center gl-overflow-hidden"
    data-testid="orbit-empty-state"
  >
    <div class="orbit-dot-grid" aria-hidden="true"></div>
    <div
      class="gl-relative gl-flex gl-w-full gl-max-w-xl gl-flex-col gl-items-center gl-gap-6 gl-overflow-hidden gl-p-8 gl-text-center"
    >
      <div class="gl-flex gl-items-center gl-gap-3">
        <h1 class="gl-heading-1 gl-mb-0 gl-mt-0 gl-text-heading">
          {{ s__('Orbit|Orbit') }}
        </h1>
        <gl-badge variant="info">{{ s__('Orbit|Beta') }}</gl-badge>
      </div>

      <p class="gl-mb-0">
        {{
          s__(
            "Orbit|Orbit is GitLab's knowledge graph, giving agents structured understanding of your projects and how everything relates. Turn on Orbit to use in GitLab Duo or connect via MCP.",
          )
        }}
      </p>
      <gl-link
        :href="$options.learnMorePath"
        class="gl-mb-0 gl-rounded-lg gl-bg-alpha-light-36 gl-px-3 gl-py-2 gl-text-sm gl-text-default hover:gl-text-default dark:gl-bg-alpha-dark-40"
      >
        {{ s__('Orbit|Learn more') }}
      </gl-link>
      <slot></slot>
    </div>
  </div>
</template>
