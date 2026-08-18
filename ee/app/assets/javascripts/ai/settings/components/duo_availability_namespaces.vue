<script>
import { GlButton, GlCollapse } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import { s__ } from '~/locale';
import DuoAvailabilityNamespacesFilter from './duo_availability_namespaces_filter.vue';
import DuoAvailabilityNamespacesTable from './duo_availability_namespaces_table.vue';

export default {
  name: 'DuoAvailabilityNamespaces',
  components: {
    GlButton,
    GlCollapse,
    DuoAvailabilityNamespacesFilter,
    DuoAvailabilityNamespacesTable,
  },
  data() {
    return {
      isExpanded: false,
      collapseId: uniqueId('duo-availability-namespaces-'),
      filter: { adminLocked: true },
    };
  },
  computed: {
    toggleExpandLabel() {
      return this.isExpanded
        ? this.$options.i18n.hideGroupsLabel
        : this.$options.i18n.showGroupsLabel;
    },
    toggleExpandIcon() {
      return this.isExpanded ? 'chevron-down' : 'chevron-right';
    },
  },
  methods: {
    onToggleExpand() {
      this.isExpanded = !this.isExpanded;
    },
    onFilter(filter) {
      this.filter = filter;
    },
  },
  i18n: {
    hideGroupsLabel: s__('AiPowered|Hide groups'),
    showGroupsLabel: s__('AiPowered|Show groups'),
  },
};
</script>

<template>
  <section data-testid="duo-availability-namespaces">
    <h3 class="gl-heading-5 gl-mb-2 gl-mt-0">
      {{ s__('AiPowered|Group Duo availability') }}
    </h3>
    <p class="gl-mb-3 gl-text-subtle">
      {{
        s__(
          'AiPowered|Override the instance-wide GitLab Duo availability for individual groups. Changes cascade to subgroups unless overridden.',
        )
      }}
    </p>

    <gl-button
      variant="link"
      :icon="toggleExpandIcon"
      :aria-expanded="isExpanded ? 'true' : 'false'"
      :aria-controls="collapseId"
      data-testid="duo-availability-namespaces-expand-toggle"
      @click="onToggleExpand"
    >
      {{ toggleExpandLabel }}
    </gl-button>

    <gl-collapse
      :id="collapseId"
      :visible="isExpanded"
      class="gl-mt-3"
      data-testid="duo-availability-namespaces-collapse"
    >
      <duo-availability-namespaces-filter class="gl-mb-4" @filter="onFilter" />
      <duo-availability-namespaces-table :filter="filter" :enabled="isExpanded" />
    </gl-collapse>
  </section>
</template>
