<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { n__, s__ } from '~/locale';
import organizationsQuery from '~/organizations/shared/graphql/queries/organizations.query.graphql';
import { SELECTIVE_SYNC_ORGANIZATIONS } from 'ee/geo_site_form/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  name: 'GeoSiteFormOrganizations',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    selectedOrganizationIds: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['update-sync-options'],
  apollo: {
    organizations: {
      query: organizationsQuery,
      variables() {
        return { search: this.searchTerm };
      },
      update(data) {
        if (!data?.organizations?.nodes) return [];

        return data.organizations.nodes.map((node) => ({
          text: node.name,
          value: getIdFromGraphQLId(node.id),
        }));
      },
      result({ data }) {
        if (!data?.organizations?.pageInfo) return;

        this.pageInfo = data.organizations.pageInfo;
      },
      error(error) {
        createAlert({
          message: s__("Geo|There was an error fetching the Site's Organizations"),
          error,
          captureError: true,
        });
      },
    },
  },
  data() {
    return {
      searchTerm: '',
      organizations: [],
      pageInfo: {},
      isLoadingMore: false,
    };
  },
  computed: {
    isSearching() {
      return this.$apollo.queries.organizations.loading && !this.isLoadingMore;
    },
    dropdownTitle() {
      const selectedCount = this.selectedOrganizationIds.length;
      return selectedCount
        ? n__('Geo|%d organization selected', 'Geo|%d organizations selected', selectedCount)
        : s__('Geo|Select organizations to replicate');
    },
  },
  methods: {
    handleSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
      this.$apollo.queries.organizations.refetch();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    handleSelect(items) {
      this.$emit('update-sync-options', { key: SELECTIVE_SYNC_ORGANIZATIONS, value: items });
    },
    handleReset() {
      this.$emit('update-sync-options', { key: SELECTIVE_SYNC_ORGANIZATIONS, value: [] });
    },
    async loadMoreOrganizations() {
      if (!this.pageInfo.hasNextPage) return;

      this.isLoadingMore = true;

      try {
        await this.$apollo.queries.organizations.fetchMore({
          variables: {
            ...this.$apollo.queries.organizations.variables,
            after: this.pageInfo.endCursor,
          },
          updateQuery: (previousResult, { fetchMoreResult }) => {
            if (!fetchMoreResult?.organizations?.nodes?.length) return previousResult;

            return {
              organizations: {
                ...fetchMoreResult.organizations,
                nodes: [
                  ...previousResult.organizations.nodes,
                  ...fetchMoreResult.organizations.nodes,
                ],
              },
            };
          },
        });
      } finally {
        this.isLoadingMore = false;
      }
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :header-text="__('Select organizations')"
    :reset-button-label="__('Clear all')"
    :items="organizations"
    :selected="selectedOrganizationIds"
    :toggle-text="dropdownTitle"
    :searching="isSearching"
    :infinite-scroll-loading="isLoadingMore"
    :no-results-text="s__('Geo|Nothing found…')"
    searchable
    multiple
    infinite-scroll
    @search="handleSearch"
    @select="handleSelect"
    @reset="handleReset"
    @bottom-reached="loadMoreOrganizations"
  />
</template>
