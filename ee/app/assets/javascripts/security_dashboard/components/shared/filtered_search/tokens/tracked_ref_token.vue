<script>
import {
  GlBadge,
  GlFilteredSearchToken,
  GlDropdownDivider,
  GlDropdownSectionHeader,
  GlLoadingIcon,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { ALL_ID } from 'ee/security_dashboard/components/shared/filtered_search/constants';
import securityTrackedRefsQuery from 'ee/security_dashboard/graphql/queries/security_tracked_refs.query.graphql';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_SECURITY_PROJECT_TRACKED_CONTEXT } from 'ee/graphql_shared/constants';
import { InternalEvents } from '~/tracking';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';

// URL parameter format: {numericId}~{refName}
// Example: "123~main" or "456~release/v1.0"
// We use tilde as separator because git prohibits it in ref names (see git-check-ref-format).
const SEPARATOR = '~';
// The `~name` suffix is optional: external links (e.g. the security
// dashboard charts) might only send the numeric ID
const QUERY_PARAM_PATTERN = new RegExp(`^(?<id>[0-9]+)(?:${SEPARATOR}(?<name>.*))?$`);

const isAllId = (value) => value === ALL_ID;
const isNotAll = (value) => !isAllId(value);

export default {
  name: 'TrackedRefToken',
  defaultValues: ({ defaultBranchContext = null }) => {
    if (!defaultBranchContext) {
      return [];
    }

    return [{ id: defaultBranchContext.id, name: defaultBranchContext.name }];
  },
  transformFilters: (filters) => {
    const trackedRefIds = filters.filter(isNotAll).map((value) => value.id);
    return {
      // Return undefined when empty so GraphQL queries receive no filter
      trackedRefIds: trackedRefIds.length > 0 ? trackedRefIds : undefined,
    };
  },
  transformQueryParams: (filters, { multiSelect } = {}) => {
    const parameterPairs = filters.filter(isNotAll).map(({ id, name }) => {
      const numericId = getIdFromGraphQLId(id);
      return name ? `${numericId}${SEPARATOR}${name}` : `${numericId}`;
    });

    if (parameterPairs.length > 0) {
      return parameterPairs.join(',');
    }

    // Multi-select treats "cleared" as ALL and persists it in the URL;
    // single-select omits the param so `defaultValues()` can re-apply the default branch.
    return multiSelect ? ALL_ID : undefined;
  },
  parseQueryParams: (urlValues, { multiSelect } = {}) => {
    if (multiSelect && urlValues.includes(ALL_ID)) {
      return [ALL_ID];
    }

    return urlValues
      .map((encoded) => encoded.match(QUERY_PARAM_PATTERN)?.groups)
      .filter(Boolean)
      .map(({ id, name }) => ({
        id: convertToGraphQLId(TYPENAME_SECURITY_PROJECT_TRACKED_CONTEXT, id),
        name: name ?? '',
      }));
  },
  apollo: {
    fetchedTrackedRefs: {
      query: securityTrackedRefsQuery,
      variables() {
        return { fullPath: this.projectFullPath };
      },
      update(data) {
        return (
          data?.project?.securityTrackedRefs?.nodes.map((ref) => ({
            id: ref.id,
            name: ref.name,
            refType: ref.refType,
          })) || []
        );
      },
      result({ data }) {
        if (data?.project?.securityTrackedRefs) {
          this.fetchSucceeded = true;
          this.removeStaleRefs();
        }
      },
      error() {
        this.fetchSucceeded = false;
        createAlert({ message: s__('SecurityReports|Failed to load tracked refs.') });
      },
    },
  },
  components: {
    GlBadge,
    GlFilteredSearchToken,
    GlDropdownDivider,
    GlDropdownSectionHeader,
    GlLoadingIcon,
    SearchSuggestion,
  },
  mixins: [InternalEvents.mixin(), glListenersMixin],
  inject: {
    defaultBranchContext: {
      default: () => null,
    },
    projectFullPath: {
      default: '',
    },
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return { selectedRefs: this.value.data || [], fetchedTrackedRefs: [], fetchSucceeded: false };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.fetchedTrackedRefs.loading;
    },
    trackedRefs() {
      // Start with the default branch (provided synchronously via inject)
      const defaultRef = this.defaultBranchContext;

      const fetchedRefsWithoutDefault = this.fetchedTrackedRefs.filter(
        (r) => r.id !== defaultRef?.id,
      );

      const knownRefs = [defaultRef, ...fetchedRefsWithoutDefault].filter(Boolean);

      // While fetch is pending, include refs parsed from URL params.
      // This allows the UI to display user-selected refs before the async fetch completes.
      if (this.isLoading) {
        const refsFromQueryParams = this.selectedRefs
          .filter(isNotAll)
          .filter((ref) => !knownRefs.some((kr) => kr.id === ref.id));

        return [...knownRefs, ...refsFromQueryParams];
      }

      return knownRefs;
    },
    isMultiSelect() {
      return this.config.multiSelect;
    },
    tokenValue() {
      return {
        ...this.value,
        data: this.active ? null : this.selectedRefs,
      };
    },
    refGroups() {
      const branchOptions = this.getRefByType('branch').map(this.createOption);
      const tagOptions = this.getRefByType('tag').map(this.createOption);

      const groups = [];

      if (this.isMultiSelect) {
        groups.push({
          text: '',
          options: [
            {
              value: ALL_ID,
              text: s__('SecurityReports|All tracked refs'),
            },
          ],
        });
      }

      if (branchOptions.length) {
        groups.push({
          text: s__('SecurityReports|Branches'),
          options: branchOptions,
          icon: 'branch',
        });
      }

      if (tagOptions.length) {
        groups.push({
          text: s__('SecurityReports|Tags'),
          options: tagOptions,
          icon: 'tag',
        });
      }

      return groups;
    },
    allRefItems() {
      const trackedRefOptions = this.trackedRefs.map((ref) => ({
        value: ref.id,
        text: ref.name,
      }));

      if (!this.isMultiSelect) {
        return trackedRefOptions;
      }

      const allOption = {
        value: ALL_ID,
        text: s__('SecurityReports|All tracked refs'),
      };

      return [allOption, ...trackedRefOptions];
    },
    selectedRefIds() {
      return this.selectedRefs.map((r) => (isAllId(r) ? ALL_ID : r.id));
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.allRefItems,
        selected: this.selectedRefIds,
        placeholder: this.isMultiSelect
          ? s__('SecurityReports|All tracked refs')
          : s__('SecurityReports|Select a ref'),
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    removeStaleRefs() {
      const validIds = new Set(this.trackedRefs.map((r) => r.id));
      const validSelected = this.selectedRefs.filter((r) => isAllId(r) || validIds.has(r.id));

      // Only update if something was filtered out
      if (validSelected.length !== this.selectedRefs.length) {
        this.selectedRefs = validSelected.length > 0 ? validSelected : [ALL_ID];
      }
    },
    getRefByType(type) {
      return this.trackedRefs.filter((ref) => ref.refType?.toLowerCase() === type);
    },
    createOption(ref) {
      return {
        value: ref.id,
        text: ref.name,
      };
    },
    handleSelect(refId) {
      this.updateSelected(refId);
      this.trackFilterEvent();
    },
    updateSelected(refId) {
      const allRefsSelected = isAllId(refId);
      if (allRefsSelected) {
        this.selectedRefs = [ALL_ID];
        return;
      }

      const ref = this.trackedRefs.find((r) => r.id === refId);

      // Single-select mode: replace selection
      if (!this.isMultiSelect) {
        this.selectedRefs = [ref];
        return;
      }

      // Multi-select mode: toggle selection
      const isSelecting = !this.isRefIdSelected(refId);
      if (isSelecting) {
        this.selectedRefs = this.selectedRefs.filter(isNotAll).concat(ref);
      } else {
        this.selectedRefs = this.selectedRefs.filter((r) => r.id !== refId);
      }

      if (this.selectedRefs.length === 0) {
        this.selectedRefs = [ALL_ID];
      }
    },
    isDefaultRef(ref) {
      return ref.id === this.defaultBranchContext?.id;
    },
    trackFilterEvent() {
      const hasNonDefaultRefSelected = this.selectedRefs.some(
        (ref) => isAllId(ref) || !this.isDefaultRef(ref),
      );
      if (hasNonDefaultRefSelected) {
        this.trackEvent('applied_non_default_branch_filter');
      }
    },
    isRefIdSelected(refId) {
      return this.selectedRefs.some((r) => (r === ALL_ID ? refId === ALL_ID : r.id === refId));
    },
  },
  i18n: {
    label: s__('SecurityReports|Tracked ref'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedRefs"
    :value="tokenValue"
    v-on="glListeners()"
    @select="handleSelect"
  >
    <template #view>
      <gl-loading-icon v-if="isLoading && !toggleText" size="sm" />
      <span data-testid="toggle-text">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoading" size="sm" />
      <template v-else>
        <template v-for="(group, index) in refGroups">
          <gl-dropdown-section-header v-if="group.text" :key="group.text">
            <div class="gl-flex gl-items-center gl-justify-center">
              <div class="gl-grow">{{ group.text }}</div>
              <gl-badge v-if="group.icon" :icon="group.icon" variant="neutral" aria-hidden="true" />
            </div>
          </gl-dropdown-section-header>
          <search-suggestion
            v-for="ref in group.options"
            :key="ref.value"
            :value="ref.value"
            :text="ref.text"
            :selected="isRefIdSelected(ref.value)"
            :data-testid="`suggestion-${ref.value}`"
          />
          <gl-dropdown-divider v-if="index < refGroups.length - 1" :key="`divider-${group.text}`" />
        </template>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
