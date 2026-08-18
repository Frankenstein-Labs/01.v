<script>
import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import projectIdentifiersQuery from 'ee/security_dashboard/graphql/queries/project_identifiers.query.graphql';
import groupIdentifiersQuery from 'ee/security_dashboard/graphql/queries/group_identifiers.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';

const MIN_CHARS = 3;

export default {
  components: {
    GlFilteredSearchToken,
    GlLoadingIcon,
    SearchSuggestion,
  },
  mixins: [glListenersMixin],
  inject: {
    projectFullPath: {
      default: '',
    },
    groupFullPath: {
      default: '',
    },
  },
  transformFilters: (filters) => {
    const identifierName = Array.isArray(filters) ? filters[0] : filters;

    return {
      identifierName: identifierName?.replace(/^"|"$/g, ''),
    };
  },
  transformQueryParams: (params) => {
    return Array.isArray(params) ? params[0] : params;
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    identifiers: {
      query() {
        return this.queryConfig.query || '';
      },
      debounce: 300,
      variables() {
        return {
          searchTerm: this.searchTerm,
          fullPath: this.queryConfig.fullPath || '',
        };
      },
      update(data) {
        return data?.[this.queryConfig?.dataPath].vulnerabilityIdentifierSearch || [];
      },
      result() {
        this.isLoadingIdentifiers = false;
      },
      error() {
        this.isLoadingIdentifiers = false;

        createAlert({
          message: this.$options.i18n.fetchErrorMessage,
        });
      },
      skip() {
        return this.searchTerm.length < MIN_CHARS;
      },
    },
  },
  data() {
    const searchTerm = this.value.data?.[0] || '';

    return {
      searchTerm,
      identifiers: [],
      selectedIdentifier: searchTerm,
      isLoadingIdentifiers: false, // Not using apollo.loading because debounce is used and causes a ux issue
    };
  },
  computed: {
    queryConfig() {
      const namespaceType = this.groupFullPath ? 'group' : 'project';

      const queryTypes = {
        group: {
          query: groupIdentifiersQuery,
          fullPath: this.groupFullPath,
          dataPath: 'group',
        },
        project: {
          query: projectIdentifiersQuery,
          fullPath: this.projectFullPath,
          dataPath: 'project',
        },
      };

      return queryTypes[namespaceType];
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedIdentifier,
      };
    },
    shouldShowPlaceholder() {
      return this.searchTerm.length < 3 && !this.identifiers.length;
    },
  },
  methods: {
    resetSearchTerm() {
      this.identifiers = [];
      this.searchTerm = '';
      this.selectedIdentifier = '';
    },
    setSearchTerm({ data }) {
      // User deletes identifier using backspace
      if (!data) {
        this.resetSearchTerm();
        return;
      }

      if (typeof data === 'string') {
        this.searchTerm = data;
        this.isLoadingIdentifiers = data.length >= MIN_CHARS;
      }
    },
    isIdentifierSelected(identifier) {
      return this.selectedIdentifier === identifier;
    },
    toggleSelectedIdentifier(identifier) {
      this.selectedIdentifier = identifier;
    },
  },
  i18n: {
    label: s__('SecurityReports|Identifier'),
    fetchErrorMessage: s__(
      'SecurityReports|There was an error fetching the identifiers for this project. Please try again later.',
    ),
    placeholder: s__('SecurityReports|Enter at least 3 characters to view available identifiers.'),
    noResult: s__('SecurityReports|No identifiers found.'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :value="tokenValue"
    v-on="glListeners()"
    @destroy="resetSearchTerm"
    @select="toggleSelectedIdentifier"
    @input="setSearchTerm"
  >
    <template #view>
      {{ selectedIdentifier }}
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoadingIdentifiers" size="sm" />
      <template v-else>
        <search-suggestion
          v-for="identifier in identifiers"
          :key="identifier"
          :value="identifier"
          :text="identifier"
          :selected="isIdentifierSelected(identifier)"
          :data-testid="`suggestion-${identifier}`"
        />
        <div v-if="shouldShowPlaceholder" class="gl-p-2 gl-text-subtle">
          {{ $options.i18n.placeholder }}
        </div>
        <div v-else-if="!identifiers.length" class="gl-p-2 gl-text-subtle">
          {{ $options.i18n.noResult }}
        </div>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
