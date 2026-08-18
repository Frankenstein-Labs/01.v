<script>
import { GlCard, GlLink, GlLoadingIcon, GlAlert } from '@gitlab/ui';

export default {
  name: 'DashboardListCard',
  components: {
    GlCard,
    GlLink,
    GlLoadingIcon,
    GlAlert,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    viewAllText: {
      type: String,
      required: false,
      default: '',
    },
    viewAllHref: {
      type: String,
      required: false,
      default: null,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    errorText: {
      type: String,
      required: false,
      default: '',
    },
    isEmpty: {
      type: Boolean,
      required: false,
      default: false,
    },
    emptyText: {
      type: String,
      required: false,
      default: '',
    },
  },
};
</script>

<template>
  <gl-card body-class="gl-p-0">
    <template #header>
      <div class="gl-flex gl-items-center gl-justify-between">
        <h2 class="gl-m-0 gl-text-base gl-font-bold">{{ title }}</h2>
        <gl-link v-if="viewAllHref" :href="viewAllHref" data-testid="view-all-link">
          {{ viewAllText }}
        </gl-link>
      </div>
    </template>

    <gl-loading-icon v-if="loading" size="md" class="gl-my-6" />
    <gl-alert v-else-if="errorText" variant="danger" :dismissible="false" class="gl-m-3">
      {{ errorText }}
    </gl-alert>
    <div v-else-if="isEmpty" class="gl-p-5 gl-text-center gl-text-subtle" data-testid="empty-state">
      {{ emptyText }}
    </div>
    <ul v-else class="gl-m-0 gl-list-none gl-p-0">
      <slot></slot>
    </ul>
  </gl-card>
</template>
