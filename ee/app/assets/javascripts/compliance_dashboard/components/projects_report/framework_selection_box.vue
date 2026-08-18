<script>
import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { isEqual } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import FrameworkBadge from '../shared/framework_badge.vue';
import getComplianceFrameworksCompactQuery from './graphql/get_compliance_frameworks_compact.query.graphql';

const frameworksDropdownPlaceholder = s__('ComplianceReport|Select frameworks');

export default {
  name: 'FrameworkSelectionBox',
  components: {
    FrameworkBadge,
    GlButton,
    GlCollapsibleListbox,
  },
  mixins: [glSlotsMixin],
  model: {
    prop: 'selected',
    event: 'select',
  },
  props: {
    groupPath: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    placeholder: {
      type: String,
      required: false,
      default: frameworksDropdownPlaceholder,
    },
    isFrameworkCreatingEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['create', 'select', 'update'],
  data() {
    return {
      frameworks: [],
      frameworkSearchQuery: '',
      currentSelectedFrameworks: [],
    };
  },
  apollo: {
    frameworks: {
      query: getComplianceFrameworksCompactQuery,
      variables() {
        return { fullPath: this.groupPath };
      },
      update(data) {
        return data.namespace.complianceFrameworks.nodes;
      },
      error(error) {
        createAlert({
          message: __('Something went wrong on our end.'),
        });
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    toggleText() {
      return this.getToggleText() || this.placeholder;
    },
    frameworksDropdownItems() {
      return (this.frameworks ?? [])
        .filter((entry) =>
          entry.name.toLowerCase().includes(this.frameworkSearchQuery.toLowerCase()),
        )
        .map((entry) => ({
          text: entry.name,
          color: entry.color,
          value: entry.id,
          extraAttrs: {},
        }));
    },
  },
  watch: {
    selected: {
      handler(newValue) {
        this.currentSelectedFrameworks = [...newValue];
      },
      immediate: true,
    },
  },
  methods: {
    getToggleText() {
      const maxFrameworks = 5;
      const maxTextLength = 30;

      const selectedFrameworksNames = (this.frameworks ?? [])
        .filter((f) => this.selected.includes(f.id))
        .slice(0, maxFrameworks)
        .map((f) => f.name);

      const combinedNames = selectedFrameworksNames.join(', ');

      const text =
        combinedNames.length < maxTextLength
          ? combinedNames
          : combinedNames.slice(0, maxTextLength).concat('...');
      return text;
    },
    createNewFramework() {
      this.$refs.listbox.close();
      this.$emit('create');
    },
    getFrameworkById(id) {
      return this.frameworks?.find((f) => f.id === id) || null;
    },
    updateFrameworks() {
      if (isEqual(this.selected, this.currentSelectedFrameworks)) return;
      this.$emit('update', this.currentSelectedFrameworks);
    },
    handleSelect(frameworkIds) {
      this.currentSelectedFrameworks = frameworkIds;
      // we still want to emit selection for the selection_operations.vue
      this.$emit('select', frameworkIds);
    },
  },
  i18n: {
    frameworksDropdownPlaceholder,
    createNewFramework: s__('ComplianceReport|Create a new framework'),
  },
};
</script>
<template>
  <gl-collapsible-listbox
    ref="listbox"
    :selected="currentSelectedFrameworks"
    :loading="$apollo.queries.frameworks.loading"
    :toggle-text="toggleText"
    :disabled="disabled"
    :header-text="$options.i18n.frameworksDropdownPlaceholder"
    :items="frameworksDropdownItems"
    multiple
    searchable
    role="button"
    tabindex="0"
    fluid-width
    class="gl-text-left"
    @select="handleSelect"
    @hidden="updateFrameworks"
    @search="frameworkSearchQuery = $event"
  >
    <template v-if="glSlots().toggle" #toggle><slot name="toggle"></slot></template>
    <template #list-item="{ item }">
      <div class="gl-mr-2">
        <framework-badge popover-mode="hidden" :framework="getFrameworkById(item.value)" />
      </div>
    </template>
    <template #footer>
      <div
        v-if="isFrameworkCreatingEnabled"
        class="gl-flex gl-flex-col gl-border-t-1 gl-border-t-default !gl-p-2 !gl-pt-0 gl-border-t-solid"
      >
        <gl-button
          category="tertiary"
          block
          class="!gl-mt-2 !gl-justify-start"
          @click="createNewFramework"
        >
          {{ $options.i18n.createNewFramework }}
        </gl-button>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
