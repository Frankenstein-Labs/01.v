<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import { debounce, get, keyBy, set, uniqBy } from 'lodash-es';
import produce from 'immer';
import { n__, s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import getSppLinkedProjectGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups.graphql';
import getDescendantGroups from 'ee/security_orchestration/graphql/queries/get_descendant_groups.query.graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import BaseItemsDropdown from './base_items_dropdown.vue';
import ProjectsCountMessage from './projects_count_message.vue';

const QUERY_TYPE_CSP = 'csp';
const QUERY_TYPE_DESCENDANT = 'descendant';
const QUERY_TYPE_LINKED = 'linked';

const getQueryVariables = (
  queryType,
  { searchTerm, withProjectCount, fullPath, includeDescendants },
) => {
  if (queryType === QUERY_TYPE_CSP) {
    return {
      search: searchTerm,
      withCount: withProjectCount,
    };
  }

  if (queryType === QUERY_TYPE_DESCENDANT) {
    return {
      rootNamespacePath: fullPath,
      search: searchTerm,
      withCount: withProjectCount,
    };
  }

  const isSearching = searchTerm.length > 0;

  return {
    fullPath,
    includeParentDescendants: isSearching || includeDescendants,
    search: '',
    descendantSearch: searchTerm,
    withCount: withProjectCount,
  };
};

const QUERY_CONFIGS = {
  [QUERY_TYPE_CSP]: {
    query: getGroups,
    dataPath: 'groups.nodes',
    pageInfoPath: 'groups.pageInfo',
    countPath: 'groups.count',
  },
  [QUERY_TYPE_DESCENDANT]: {
    query: getDescendantGroups,
    dataPath: 'group.descendantGroups.nodes',
    pageInfoPath: 'group.descendantGroups.pageInfo',
    countPath: 'group.descendantGroups.count',
  },
  [QUERY_TYPE_LINKED]: {
    query: getSppLinkedProjectGroups,
    dataPath: 'project.securityPolicyProjectLinkedGroups.nodes',
    pageInfoPath: 'project.securityPolicyProjectLinkedGroups.pageInfo',
    countPath: 'project.securityPolicyProjectLinkedGroups.count',
  },
};

export default {
  ERROR_KEY: 'linked-items-query-error',
  SECURITY_POLICY_PROJECT_PATH: helpPagePath(
    'user/application_security/policies/enforcement/security_policy_projects.md',
  ),
  i18n: {
    groupDropdownHeader: __('Select groups'),
    popoverTitle: s__('SecurityOrchestration|No linked groups'),
    popoverLink: s__('SecurityOrchestration|How do I link a group to the policy?'),
  },
  name: 'ScopedGroupsDropdown',
  components: {
    GlPopover,
    GlLink,
    BaseItemsDropdown,
    ProjectsCountMessage,
  },
  inject: ['designatedAsCsp'],
  props: {
    includeDescendants: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    state: {
      type: Boolean,
      required: false,
      default: false,
    },
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    useDescendantGroups: {
      type: Boolean,
      required: false,
      default: false,
    },
    withProjectCount: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['loaded', 'linked-items-query-error', 'select'],
  apollo: {
    groups: {
      query() {
        return this.queryConfig.query;
      },
      variables() {
        return getQueryVariables(this.queryType, {
          searchTerm: this.searchTerm,
          withProjectCount: this.withProjectCount,
          fullPath: this.fullPath,
          includeDescendants: this.includeDescendants,
        });
      },
      update(data) {
        const groups = get(data, this.queryConfig.dataPath, []);
        const getUniqueItems = (moreItems = []) =>
          uniqBy([...this.items, ...groups, ...moreItems], 'id');

        if (this.queryType === QUERY_TYPE_LINKED) {
          if (!this.allGroupsCountSaved) {
            this.allGroupsCount = this.countLinkedGroups(data, groups);
          }
          const descendants = this.flatMapDescendantGroups(groups);
          this.items = getUniqueItems(descendants);
          this.descendantPageInfo = this.extractDescendantPageInfo(groups);
        } else {
          this.items = getUniqueItems();
          this.allGroupsCount = get(data, this.queryConfig.countPath, 0);
        }

        this.pageInfo = get(data, this.queryConfig.pageInfoPath, {});
        this.$emit('loaded', this.items);
      },
      result() {
        if (this.selectedButNotLoadedGroupIds.length > 0) {
          this.fetchGroupsByIds();
        }
      },
      error() {
        this.$emit(this.$options.ERROR_KEY);
        this.$emit('loaded', this.items);
      },
    },
  },
  data() {
    return {
      items: [],
      pageInfo: {},
      descendantPageInfo: {},
      searchTerm: '',
      // eslint-disable-next-line vue/no-unused-properties -- initialized for Apollo reactivity
      groups: {},
      allGroupsCount: 0,
    };
  },
  computed: {
    queryType() {
      if (this.designatedAsCsp) {
        return QUERY_TYPE_CSP;
      }
      if (this.useDescendantGroups) {
        return QUERY_TYPE_DESCENDANT;
      }
      return QUERY_TYPE_LINKED;
    },
    queryConfig() {
      return QUERY_CONFIGS[this.queryType];
    },
    allGroupsLoaded() {
      return this.items.length === this.allGroupsCount;
    },
    allGroupsCountSaved() {
      return this.allGroupsCount > 0;
    },
    showFooter() {
      return this.withProjectCount && !this.loading;
    },
    selectedButNotLoadedGroupIds() {
      return this.selected.filter((id) => !this.itemsIds.includes(id));
    },
    category() {
      return this.state ? 'primary' : 'secondary';
    },
    variant() {
      return this.state ? 'default' : 'danger';
    },
    dropdownDisabled() {
      return this.disabled || this.showPopover;
    },
    loading() {
      return this.$apollo.queries.groups.loading;
    },
    searching() {
      return this.loading && this.searchUsed && !this.hasNextPage;
    },
    searchUsed() {
      return this.searchTerm !== '';
    },
    hasNextPage() {
      return this.pageInfo.hasNextPage || this.descendantPageInfo.hasNextPage;
    },
    listBoxItems() {
      const items = this.items.map(({ id, fullPath, name, fullName }) => ({
        text: name || fullName,
        value: id,
        fullPath,
      }));

      return searchInItemsProperties({
        items,
        properties: ['text', 'fullPath'],
        searchQuery: this.searchTerm,
      });
    },
    listBoxItemsCount() {
      return this.listBoxItems?.length || 0;
    },
    itemsIds() {
      return this.items.map(({ id }) => id);
    },
    infoText() {
      return n__('group', 'groups', this.allGroupsCount);
    },
    existingFormattedSelectedIds() {
      return this.selected.filter((id) => this.itemsIds.includes(id));
    },
    showPopover() {
      return this.queryType === QUERY_TYPE_LINKED && !this.loading && this.items.length === 0;
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    countLinkedGroups(data, groups) {
      const topLevelCount = get(data, this.queryConfig.countPath, 0);
      const descendantCounts = groups.flatMap(({ descendantGroups }) => descendantGroups.count);
      return topLevelCount + descendantCounts.reduce((total, count) => total + count, 0);
    },
    flatMapDescendantGroups(groups) {
      return groups.flatMap(({ descendantGroups }) => descendantGroups.nodes);
    },
    extractDescendantPageInfo(groups) {
      const groupWithMoreDescendants = groups.find(
        ({ descendantGroups }) => descendantGroups.pageInfo?.hasNextPage,
      );
      return groupWithMoreDescendants?.descendantGroups?.pageInfo || {};
    },
    async fetchGroupsByIds() {
      const variables = {
        topLevelOnly: false,
        ids: this.selectedButNotLoadedGroupIds,
      };

      try {
        const { data } = await this.$apollo.query({
          query: getGroups,
          variables,
        });

        this.items = uniqBy([...this.items, ...data.groups.nodes], 'id');
      } catch {
        this.$emit(this.$options.ERROR_KEY);
      }
    },
    fetchMoreItems() {
      const { dataPath } = this.queryConfig;

      if (this.queryType === QUERY_TYPE_LINKED && this.descendantPageInfo.hasNextPage) {
        this.fetchMoreDescendants();
        return;
      }

      const variables = {
        after: this.pageInfo.endCursor,
        ...(this.queryType === QUERY_TYPE_CSP ? {} : { fullPath: this.fullPath }),
      };

      this.$apollo.queries.groups
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              const data = [...get(previousResult, dataPath, []), ...get(draftData, dataPath, [])];
              set(draftData, dataPath, data);
            });
          },
        })
        .catch(() => {
          this.$emit(this.$options.ERROR_KEY);
        });
    },
    fetchMoreDescendants() {
      const { dataPath } = this.queryConfig;

      const variables = {
        afterDescendants: this.descendantPageInfo.endCursor,
        fullPath: this.fullPath,
      };

      this.$apollo.queries.groups
        .fetchMore({
          variables,
          updateQuery(previousResult, { fetchMoreResult }) {
            return produce(fetchMoreResult, (draftData) => {
              const previousNodes = get(previousResult, dataPath, []);
              const newNodes = get(draftData, dataPath, []);

              const newNodesById = keyBy(newNodes, 'id');
              const mergedNodes = previousNodes.map((prevNode) => {
                const newNode = newNodesById[prevNode.id];
                if (!newNode?.descendantGroups?.nodes) return prevNode;

                return {
                  ...newNode,
                  descendantGroups: {
                    ...newNode.descendantGroups,
                    nodes: [
                      ...(prevNode.descendantGroups?.nodes || []),
                      ...newNode.descendantGroups.nodes,
                    ],
                  },
                };
              });

              set(draftData, dataPath, mergedNodes);
            });
          },
        })
        .catch(() => {
          this.$emit(this.$options.ERROR_KEY);
        });
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
      this.descendantPageInfo = {};
    },
    selectItems(selected) {
      const selectedItems = this.items.filter(({ id }) => selected.includes(id));
      this.$emit('select', selectedItems);
    },
  },
};
</script>

<template>
  <div>
    <gl-popover
      v-if="showPopover"
      boundary="viewport"
      triggers="manual blur"
      target="scoped-groups"
      placement="bottom"
      show-close-button
      :show="true"
    >
      <p>{{ $options.i18n.popoverTitle }}</p>
      <gl-link :href="$options.SECURITY_POLICY_PROJECT_PATH" target="_blank">
        {{ $options.i18n.popoverLink }}
      </gl-link>
    </gl-popover>

    <base-items-dropdown
      id="scoped-groups"
      multiple
      :category="category"
      :variant="variant"
      :disabled="dropdownDisabled"
      :loading="loading"
      :header-text="$options.i18n.groupDropdownHeader"
      :items="listBoxItems"
      :infinite-scroll="hasNextPage"
      :searching="searching"
      :selected="existingFormattedSelectedIds"
      :item-type-name="__('groups')"
      @bottom-reached="fetchMoreItems"
      @search="debouncedSearch"
      @reset="selectItems([])"
      @select="selectItems"
      @select-all="selectItems"
    >
      <template v-if="showFooter" #footer>
        <div
          class="gl-border-t gl-flex gl-items-center gl-gap-3 gl-px-4 gl-py-3"
          data-testid="footer"
        >
          <projects-count-message
            :count="listBoxItemsCount"
            :info-text="infoText"
            :total-count="allGroupsCount"
            :show-info-icon="!allGroupsLoaded"
          />
        </div>
      </template>
    </base-items-dropdown>
  </div>
</template>
