<script>
import { GlButton, GlCard, GlLink, GlSkeletonLoader } from '@gitlab/ui';
import { GlSingleStat } from '@gitlab/ui/src/charts';

export default {
  name: 'StatisticsCardRow',
  components: {
    GlButton,
    GlCard,
    GlLink,
    GlSkeletonLoader,
    GlSingleStat,
  },
  props: {
    cards: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    error: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['view-projects'],
};
</script>

<template>
  <div class="gl-mb-4 gl-grid gl-grid-cols-2 gl-gap-4 md:gl-grid-cols-4">
    <template v-if="loading">
      <gl-card v-for="n in cards.length" :key="n">
        <gl-skeleton-loader :lines="2" />
      </gl-card>
    </template>
    <template v-else>
      <gl-card
        v-for="card in cards"
        :key="card.title"
        header-class="gl-font-bold"
        body-class="gl-flex gl-flex-col"
      >
        <template #header>{{ card.title }}</template>
        <gl-single-stat title="" :value="error ? __('—') : card.value" />
        <span class="gl-mt-auto gl-text-subtle">{{ card.description }}</span>
        <hr class="gl-my-3" />
        <gl-link v-if="card.linkText && card.to" class="gl-self-start" :to="card.to">
          {{ card.linkText }}
        </gl-link>
        <gl-button
          v-else
          class="gl-self-start"
          variant="link"
          @click="$emit('view-projects', card)"
        >
          {{ __('View projects') }}
        </gl-button>
      </gl-card>
    </template>
  </div>
</template>
