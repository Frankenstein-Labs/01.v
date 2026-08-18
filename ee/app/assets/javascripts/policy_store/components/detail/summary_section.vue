<script>
import { GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'PolicySummarySection',
  components: {
    GlIcon,
  },
  i18n: {
    noneAdded: s__('PolicyStore|None added'),
  },
  props: {
    label: {
      type: String,
      required: true,
    },
    entries: {
      type: Array,
      required: false,
      default: () => [],
    },
    testid: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <section
    class="gl-border gl-rounded-lg gl-border-default gl-p-5"
    :data-testid="`${testid}-section`"
  >
    <h2 class="gl-heading-4 gl-mb-4">{{ label }}</h2>
    <!-- The slot lets sections with bespoke content (like the scope summary)
         reuse the card chrome without faking catalog entries. -->
    <slot>
      <p v-if="!entries.length" class="gl-mb-0 gl-text-subtle">
        {{ $options.i18n.noneAdded }}
      </p>
      <div v-else class="gl-flex gl-flex-col gl-gap-4">
        <div
          v-for="entry in entries"
          :key="entry.id"
          class="gl-flex gl-items-start gl-gap-3"
          :data-testid="`${testid}-entry`"
        >
          <span
            class="gl-flex gl-h-6 gl-w-6 gl-flex-shrink-0 gl-items-center gl-justify-center gl-rounded-base gl-bg-subtle gl-text-subtle"
          >
            <gl-icon :name="entry.icon" :size="14" />
          </span>
          <span class="gl-min-w-0">
            <span class="gl-block gl-text-sm gl-font-semibold">{{ entry.label }}</span>
            <span v-if="entry.description" class="gl-mt-0.5 gl-block gl-text-xs gl-text-subtle">
              {{ entry.description }}
            </span>
          </span>
        </div>
      </div>
    </slot>
  </section>
</template>
