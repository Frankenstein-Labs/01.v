<script>
import { GlCollapsibleListbox, GlAvatarLabeled } from '@gitlab/ui';
import { uniqBy } from 'lodash-es';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import searchNamespaceGroups from 'ee/security_orchestration/graphql/queries/get_namespace_groups.query.graphql';
import searchDescendantGroups from 'ee/security_orchestration/graphql/queries/get_descendant_groups.query.graphql';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { __ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';

const createGroupObject = (group) => ({
  ...group,
  text: group.fullName,
  value: group.value || group.id,
});

export default {
  name: 'GroupSelectEE',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  apollo: {
    groups: {
      query() {
        return this.globalGroupApproversEnabled ? searchNamespaceGroups : searchDescendantGroups;
      },
      variables() {
        return {
          rootNamespacePath: this.rootNamespacePath,
          search: this.search,
        };
      },
      update(data) {
        // Handle global group approvers case (searchNamespaceGroups query)
        if (this.globalGroupApproversEnabled) {
          const groups = (data?.groups?.nodes || [])
            .filter((group) => group)
            .map(createGroupObject);
          return uniqBy([...this.groups, ...groups], 'id');
        }

        if (!data?.group) {
          return [];
        }

        // Handle descendant groups case (searchDescendantGroups query)
        const { __typename, avatarUrl, id, fullName, fullPath } = data.group;

        const descendantGroups = (data?.group?.descendantGroups?.nodes || [])
          .filter((group) => group)
          .map(createGroupObject);

        // If root group doesn't match search criteria, return only descendant groups
        if (!fullName.includes(this.search)) return descendantGroups;

        // Include root group with descendants when it matches search
        const rootGroup = createGroupObject({ __typename, avatarUrl, id, fullName, fullPath });
        return uniqBy([...this.groups, rootGroup, ...descendantGroups], 'id');
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      error() {
        this.$emit('error');
      },
    },
  },
  inject: ['globalGroupApproversEnabled', 'rootNamespacePath'],
  props: {
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    selectedNames: {
      type: Array,
      required: false,
      default: () => [],
    },
    state: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['error', 'select-items'],
  data() {
    return {
      groups: [],
      search: '',
    };
  },
  computed: {
    listBoxItems() {
      return searchInItemsProperties({
        items: this.groups,
        properties: ['text', 'fullPath', 'fullName'],
        searchQuery: this.search,
      });
    },
    selectedGraphQlIds() {
      const selected = Array.isArray(this.selected) ? this.selected : [];
      const getGraphQLIds = (ids) => ids.map((id) => convertToGraphQLId(TYPENAME_GROUP, id));
      const getGroupsByNames = (names) => {
        return this.groups
          .filter(({ text, fullPath }) => names.includes(text) || names.includes(fullPath))
          .map(({ value }) => value);
      };

      if (this.selectedNames.length === 0) {
        return getGraphQLIds(selected);
      }

      const groupsByNames = getGroupsByNames(this.selectedNames);

      if (selected.length === 0) {
        return groupsByNames;
      }

      return [...groupsByNames, ...getGraphQLIds(selected)];
    },
    groupItems() {
      return this.groups.reduce((acc, { id, fullName }) => {
        acc[id] = fullName;
        return acc;
      }, {});
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedGraphQlIds,
        items: this.groupItems,
        itemTypeName: __('groups'),
        useAllSelected: false,
      });
    },
    hasSelectedNames() {
      return this.selectedGraphQlIds.length > 0 && this.selectedNames.length > 0;
    },
  },
  updated() {
    /**
     * Edge case when instead of group ids
     * Policy has group names or fullPath it would be
     * replaced with group ids by emitting
     * change event
     */
    if (this.hasSelectedNames) {
      this.selectGroups(this.selectedGraphQlIds);
    }
  },
  methods: {
    selectGroups(groupsIds) {
      this.$emit('select-items', {
        group_approvers_ids: groupsIds.map((id) => getIdFromGraphQLId(id)),
      });
    },
    setSearch(search) {
      this.search = search;
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    searchable
    is-check-centered
    multiple
    :header-text="__('Groups')"
    :items="listBoxItems"
    :reset-button-label="__('Clear all')"
    :state="state"
    :searching="$apollo.loading"
    :loading="$apollo.loading"
    :selected="selectedGraphQlIds"
    :toggle-text="toggleText"
    @reset="selectGroups([])"
    @search="setSearch"
    @select="selectGroups"
  >
    <template #list-item="{ item }">
      <gl-avatar-labeled
        shape="circle"
        :size="32"
        :src="item.avatarUrl"
        :entity-name="item.text"
        :label="item.text"
        :sub-label="item.fullPath"
      />
    </template>
  </gl-collapsible-listbox>
</template>
