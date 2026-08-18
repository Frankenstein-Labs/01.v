<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';

import { AUDIT_STREAMS_FILTERING, MAXIMUM_NAMESPACE_FILTERS } from '../../constants';
import getNamespaceFiltersQuery from '../../graphql/queries/get_namespace_filters.query.graphql';
import getInstanceNamespaceFiltersQuery from '../../graphql/queries/get_instance_namespace_filters.query.graphql';

const MAX_OPTIONS_SHOWN = 3;

export default {
  name: 'StreamNamespaceFilters',
  components: {
    GlCollapsibleListbox,
  },
  inject: ['groupPath'],
  props: {
    value: {
      type: Array,
      required: true,
    },
  },
  emits: ['input'],
  data() {
    return {
      searchTerm: '',
      filterTargets: null,
    };
  },
  apollo: {
    filterTargets: {
      query() {
        return this.isInstance ? getInstanceNamespaceFiltersQuery : getNamespaceFiltersQuery;
      },
      variables() {
        if (this.isInstance) {
          return { search: this.searchTerm };
        }
        return { search: this.searchTerm, fullPath: this.groupPath };
      },
      update(data) {
        if (this.isInstance) {
          return {
            groups: data.groups?.nodes || [],
            projects: data.projects?.nodes || [],
          };
        }
        return {
          groups: data.group?.descendantGroups?.nodes || [],
          projects: data.group?.projects?.nodes || [],
        };
      },
      skip() {
        return !this.groupPath;
      },
    },
  },
  computed: {
    isInstance() {
      return this.groupPath === 'instance';
    },
    selectedPaths() {
      return this.value.map((v) => v.namespace).filter(Boolean);
    },
    options() {
      const result = [];
      if (this.filterTargets?.groups?.length > 0) {
        result.push({
          text: __('Groups'),
          options: this.filterTargets.groups.map((g) => ({
            text: g.name,
            value: g.fullPath,
            secondaryText: g.fullPath,
          })),
        });
      }
      if (this.filterTargets?.projects?.length > 0) {
        result.push({
          text: __('Projects'),
          options: this.filterTargets.projects.map((p) => ({
            text: p.name,
            value: p.fullPath,
            secondaryText: p.fullPath,
          })),
        });
      }
      return result;
    },
    toggleTextOptions() {
      // Combine the loaded source options with the current value (so previously selected
      // entries still render their name even before the source query resolves, or when
      // search has filtered them out of the source list).
      const fromSource = [
        ...(this.filterTargets?.groups || []),
        ...(this.filterTargets?.projects || []),
      ].map((s) => ({ value: s.fullPath, text: s.name }));

      const fromValue = this.value
        .filter((v) => !fromSource.some((s) => s.value === v.namespace))
        .map((v) => ({ value: v.namespace, text: v.name || v.namespace }));

      return [...fromSource, ...fromValue];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.toggleTextOptions,
        selected: this.selectedPaths,
        placeholder: this.$options.i18n.SELECT_NAMESPACE,
        maxOptionsShown: MAX_OPTIONS_SHOWN,
      });
    },
    selectionCountText() {
      return sprintf(this.$options.i18n.NAMESPACE_SELECTION_COUNT, {
        selected: this.selectedPaths.length,
        maximum: MAXIMUM_NAMESPACE_FILTERS,
      });
    },
    isLoading() {
      return this.$apollo.queries.filterTargets?.loading || false;
    },
  },
  methods: {
    updateSearchTerm(searchTerm) {
      this.searchTerm = searchTerm;
    },
    buildEntry(fullPath) {
      // Preserve any existing entry to keep its name across re-selections that may
      // happen after a search has narrowed the visible source items.
      const existing = this.value.find((v) => v.namespace === fullPath);
      if (existing) {
        return existing;
      }

      const group = this.filterTargets?.groups?.find((g) => g.fullPath === fullPath);
      if (group) {
        return { namespace: group.fullPath, name: group.name };
      }

      const project = this.filterTargets?.projects?.find((p) => p.fullPath === fullPath);
      if (project) {
        return { namespace: project.fullPath, name: project.name };
      }

      return null;
    },
    emitFromPaths(paths) {
      const entries = paths.map((p) => this.buildEntry(p)).filter(Boolean);
      this.$emit('input', entries.slice(0, MAXIMUM_NAMESPACE_FILTERS));
    },
    selectOption(selectedPaths) {
      this.emitFromPaths(selectedPaths);
    },
    resetOptions() {
      this.$emit('input', []);
    },
  },
  i18n: AUDIT_STREAMS_FILTERING,
};
</script>

<template>
  <gl-collapsible-listbox
    id="audit-event-namespace-filter"
    :items="options"
    :selected="selectedPaths"
    :header-text="$options.i18n.SELECT_NAMESPACE"
    :reset-button-label="$options.i18n.UNSELECT_ALL"
    :no-results-text="$options.i18n.NO_RESULT_TEXT"
    :search-placeholder="$options.i18n.SEARCH_PLACEHOLDER"
    multiple
    searchable
    :searching="isLoading"
    toggle-class="gl-max-w-full"
    :toggle-text="toggleText"
    class="gl-max-w-full"
    data-testid="namespace-filter-dropdown"
    @select="selectOption"
    @reset="resetOptions"
    @search="updateSearchTerm"
  >
    <template #footer>
      <div
        class="gl-border-t gl-px-4 gl-py-3 gl-text-sm gl-text-subtle"
        data-testid="namespace-filter-selection-count"
      >
        {{ selectionCountText }}
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
