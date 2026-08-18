<script>
import { GlIcon, GlToken, GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { __ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'StatusToken',
  statuses: [
    {
      id: 1,
      value: 'satisfied',
      text: __('Satisfied'),
      icon: 'status-success',
      containerClass: 'gl-bg-green-100 gl-text-default',
      variant: 'success',
    },
    {
      id: 2,
      value: 'failed',
      text: __('Failed'),
      icon: 'status-failed',
      containerClass: 'gl-bg-red-100 gl-text-default',
      variant: 'danger',
    },
    {
      id: 3,
      value: 'missing',
      text: __('Missing'),
      icon: 'status-waiting',
      containerClass: 'gl-bg-gray-100 gl-text-default',
      variant: 'current',
    },
  ],
  components: {
    GlIcon,
    GlToken,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
  },
  mixins: [glListenersMixin],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  computed: {
    activeStatus() {
      return this.$options.statuses.find((status) => status.value === this.value.data);
    },
  },
};
</script>

<template>
  <gl-filtered-search-token v-bind="{ ...$props, ...$attrs }" v-on="glListeners()">
    <template #view-token>
      <gl-token
        v-if="activeStatus"
        variant="search-value"
        :class="['gl-flex', activeStatus.containerClass]"
      >
        <gl-icon :name="activeStatus.icon" :variant="activeStatus.variant" />
        <div class="gl-ml-2">{{ activeStatus.text }}</div>
      </gl-token>
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="status in $options.statuses"
        :key="status.id"
        :value="status.value"
      >
        <div class="gl-flex">
          <gl-icon :name="status.icon" :variant="status.variant" />
          <div class="gl-ml-2">{{ status.text }}</div>
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
