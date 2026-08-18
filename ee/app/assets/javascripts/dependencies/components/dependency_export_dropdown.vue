<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlTooltipDirective } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';
import {
  EXPORT_FORMAT_CSV,
  EXPORT_FORMAT_DEPENDENCY_LIST,
  EXPORT_FORMAT_JSON_ARRAY,
  EXPORT_FORMAT_CYCLONEDX_1_6_JSON,
  NAMESPACE_GROUP,
  NAMESPACE_PROJECT,
} from '../constants';

const availableForContainers = (supportedContainers) => {
  return (component) => supportedContainers.includes(component.container);
};

const exportFormats = [
  {
    type: EXPORT_FORMAT_DEPENDENCY_LIST,
    buttonText: s__('Dependencies|Export as JSON'),
    testid: 'dependency-list-item',
    available: availableForContainers([NAMESPACE_PROJECT]),
  },
  {
    type: EXPORT_FORMAT_JSON_ARRAY,
    buttonText: s__('Dependencies|Export as JSON'),
    testid: 'json-array-item',
    available: availableForContainers([NAMESPACE_GROUP]),
  },
  {
    type: EXPORT_FORMAT_CSV,
    buttonText: s__('Dependencies|Export as CSV'),
    testid: 'csv-item',
    available: availableForContainers([NAMESPACE_PROJECT, NAMESPACE_GROUP]),
  },
  {
    type: EXPORT_FORMAT_CYCLONEDX_1_6_JSON,
    buttonText: s__('Dependencies|Export as CycloneDX (JSON)'),
    testid: 'cyclonedx-1-6-item',
    available: availableForContainers([NAMESPACE_PROJECT]),
  },
];

export default {
  name: 'DependencyExportDropdown',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    // Used in availability check.
    // eslint-disable-next-line vue/no-unused-properties
    container: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState(['fetchingInProgress']),
    availableFormats() {
      return exportFormats.filter((format) => format.available(this));
    },
    exportButtonIcon() {
      return this.fetchingInProgress ? '' : 'export';
    },
  },
  methods: {
    ...mapActions({
      createExport(dispatch, type) {
        return dispatch('fetchExport', { export_type: type });
      },
    }),
  },
};
</script>

<template>
  <gl-disclosure-dropdown
    :icon="exportButtonIcon"
    :loading="fetchingInProgress"
    :toggle-text="__('Export')"
    data-testid="export-disclosure"
  >
    <gl-disclosure-dropdown-item
      v-for="format in availableFormats"
      :key="format.type"
      :data-testid="format.testid"
      @action="createExport(format.type)"
    >
      <template #list-item>
        {{ format.buttonText }}
      </template>
    </gl-disclosure-dropdown-item>
  </gl-disclosure-dropdown>
</template>
