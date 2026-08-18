<script>
import { GlIntersectionObserver, GlLoadingIcon, GlEmptyState } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { SIDEBAR_SEARCH_DEBOUNCE } from '../../constants';
import SubgroupsQuery from '../../graphql/subgroups.query.graphql';
import ExpandableGroup from './expandable_group.vue';

export default {
  components: {
    ExpandableGroup,
    GlIntersectionObserver,
    GlLoadingIcon,
    GlEmptyState,
  },
  props: {
    groupFullPath: {
      type: String,
      required: true,
    },
    activeFullPath: {
      type: String,
      required: false,
      default: '',
    },
    search: {
      type: String,
      required: false,
      default: '',
    },
    indentation: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: ['select-subgroup'],
  data() {
    return {
      group: {
        descendantGroups: {
          edges: [],
        },
      },
    };
  },
  apollo: {
    group: {
      query: SubgroupsQuery,
      client: 'appendGroupsClient',
      variables() {
        return {
          fullPath: this.groupFullPath,
          hasSearch: this.hasSearch,
          search: this.hasSearch ? this.search : '',
        };
      },
      error(error) {
        createAlert({
          message: s__(
            'SecurityInventory|An error occurred while fetching subgroups. Please try again.',
          ),
          error,
          captureError: true,
        });
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isEmpty() {
      return !this.$apollo.queries.group.loading && !this.group.descendantGroups.edges.length;
    },
    hasSearch() {
      return Boolean(this.search?.length >= 3);
    },
  },
  watch: {
    search: debounce(function debouncedSubgroupSearch() {
      if (this.search.length === 0 || this.hasSearch) {
        this.$apollo.queries.group.refetch();
      }
    }, SIDEBAR_SEARCH_DEBOUNCE),
  },
  methods: {
    selectSubgroup(subgroupFullPath) {
      this.$emit('select-subgroup', subgroupFullPath);
    },
    fetchMoreSubgroups() {
      const { hasNextPage, endCursor } = this.group.descendantGroups.pageInfo || {};
      if (!hasNextPage) return;
      this.$apollo.queries.group.fetchMore({ variables: { after: endCursor } });
    },
  },
};
</script>
<template>
  <div>
    <expandable-group
      v-for="subgroup in group.descendantGroups.edges.map((edge) => edge.node)"
      :key="subgroup.id"
      :group="subgroup"
      :active-full-path="activeFullPath"
      :indentation="indentation"
      :has-search="hasSearch"
      class="gl-w-auto"
      @select-subgroup="selectSubgroup"
    />
    <gl-empty-state
      v-if="isEmpty"
      :description="s__(`SecurityInventory|This group doesn't have any subgroups.`)"
    >
      <template #title>
        <strong>{{ s__('SecurityInventory|No subgroups found') }}</strong>
      </template>
    </gl-empty-state>
    <gl-loading-icon v-if="$apollo.queries.group.loading" class="gl-pt-3" />
    <gl-intersection-observer v-else @appear="fetchMoreSubgroups" />
  </div>
</template>
