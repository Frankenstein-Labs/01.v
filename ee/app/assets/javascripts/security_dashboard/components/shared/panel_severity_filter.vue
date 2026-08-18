<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import { ALL_ID } from './filtered_search/constants';

export default {
  name: 'PanelSeverityFilter',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    value: {
      type: Array,
      required: true,
      default: () => [],
    },
  },
  emits: ['input'],
  computed: {
    severityFilterListboxItems() {
      const allOption = { value: ALL_ID, text: s__('SecurityReports|All severities') };

      return [allOption, ...this.$options.SEVERITY_FILTER_LISTBOX_ITEMS];
    },
    severityFilterToggleText() {
      return getSelectedOptionsText({
        options: this.severityFilterListboxItems,
        selected: this.value,
        placeholder: s__('SecurityReports|All severities'),
      });
    },
    selectedSeverities() {
      return this.value.length ? this.value : [ALL_ID];
    },
  },
  methods: {
    updateSelected(selected) {
      if (selected.at(-1) === ALL_ID) {
        this.$emit('input', []);
      } else {
        this.$emit(
          'input',
          selected.filter((s) => s !== ALL_ID),
        );
      }
    },
  },
  SEVERITY_FILTER_LISTBOX_ITEMS: Object.entries(SEVERITY_LEVELS).map(([key, value]) => ({
    text: value,
    value: key.toUpperCase(),
  })),
};
</script>

<template>
  <gl-collapsible-listbox
    :items="severityFilterListboxItems"
    :selected="selectedSeverities"
    block
    multiple
    class="gl-w-15 gl-flex-shrink-0"
    size="small"
    :toggle-text="severityFilterToggleText"
    @select="updateSelected"
  />
</template>
