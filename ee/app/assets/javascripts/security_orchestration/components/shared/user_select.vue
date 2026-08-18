<script>
import { uniqBy } from 'lodash-es';
import { GlAvatarLabeled, GlCollapsibleListbox } from '@gitlab/ui';
import { __ } from '~/locale';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { isProject } from 'ee/security_orchestration/components/utils';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';

const createUserObject = (user) => ({
  ...user,
  text: user.name,
  username: `@${user.username}`,
  value: user.value || user.id,
});

export default {
  name: 'UserSelectEE',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    state: {
      type: Boolean,
      required: false,
      default: true,
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
    selectedNames: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['error', 'select-items'],
  apollo: {
    users: {
      query() {
        return this.query;
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          search: this.search,
        };
      },
      update(data) {
        const users = this.extractUsers(data);
        const accumulatedUsers = [...this.users, ...users];

        return uniqBy(accumulatedUsers, 'id');
      },
      result() {
        if (this.selectedButNotLoadedUsersIds.length > 0) {
          this.fetchUsersByIds();
        }
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      error() {
        this.emitError();
      },
    },
  },
  data() {
    return {
      search: '',
      users: [],
    };
  },
  computed: {
    query() {
      return isProject(this.namespaceType) ? searchProjectMembers : searchGroupMembers;
    },
    selectedButNotLoadedUsersIds() {
      return this.selectedGraphQlIds.filter((id) => !this.userIds.includes(id));
    },
    userIds() {
      return this.users?.map(({ id }) => id);
    },
    listBoxItems() {
      return searchInItemsProperties({
        items: this.users,
        properties: ['text', 'username'],
        searchQuery: this.search,
      });
    },
    userItems() {
      return this.users.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    selectedGraphQlIds() {
      const removeAtSymbol = (username = '') =>
        username.startsWith('@') ? username.substring(1) : username;

      const getUsersByNames = (names) => {
        const normalizedNames = names.map(removeAtSymbol);
        return this.users
          .filter(({ username }) => normalizedNames.includes(removeAtSymbol(username)))
          .map(({ value }) => value);
      };

      const getGraphQLIds = (ids) => ids.map((id) => convertToGraphQLId(TYPENAME_USER, id));

      if (this.selectedNames.length === 0) {
        return getGraphQLIds(this.selected);
      }

      const usersByNames = getUsersByNames(this.selectedNames);

      if (this.selected.length === 0) {
        return usersByNames;
      }

      return [...usersByNames, ...getGraphQLIds(this.selected)];
    },
    toggleText() {
      return renderMultiSelectText({
        selected: this.selectedGraphQlIds,
        items: this.userItems,
        itemTypeName: __('users'),
        useAllSelected: false,
      });
    },
    hasSelectedNames() {
      return this.selectedGraphQlIds.length > 0 && this.selectedNames.length > 0;
    },
  },
  updated() {
    /**
     * Edge case when instead of user ids
     * Policy has user names it would be
     * replaced with user ids by emitting
     * change event
     */
    if (this.hasSelectedNames) {
      this.selectUsers(this.selectedGraphQlIds);
    }
  },
  methods: {
    emitError() {
      this.$emit('error');
    },
    extractUsers(data) {
      const nodes = isProject(this.namespaceType)
        ? data?.project?.projectMembers?.nodes
        : data?.namespace?.users?.nodes;

      return (nodes || []).filter(({ user }) => user).map(({ user }) => createUserObject(user));
    },
    setSearch(value) {
      this.search = value?.trim();
    },
    selectUsers(userIds) {
      this.$emit('select-items', {
        user_approvers_ids: userIds.map((id) => getIdFromGraphQLId(id)),
      });
    },
    getUniqueUsers(items = []) {
      return uniqBy([...this.users, ...items], 'id');
    },
    async fetchUsersByIds() {
      try {
        const { data } = await this.$apollo.query({
          query: this.query,
          variables: {
            fullPath: this.namespacePath,
            search: this.search,
            ids: this.selectedButNotLoadedUsersIds,
          },
        });

        this.users = this.getUniqueUsers(this.extractUsers(data));
      } catch {
        this.emitError();
      }
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="listBoxItems"
    :disabled="disabled"
    block
    searchable
    is-check-centered
    multiple
    :header-text="__('Users')"
    :reset-button-label="__('Clear all')"
    :state="state"
    :searching="$apollo.loading"
    :loading="$apollo.loading"
    :selected="selectedGraphQlIds"
    :toggle-text="toggleText"
    @reset="selectUsers([])"
    @search="setSearch"
    @select="selectUsers"
  >
    <template #list-item="{ item }">
      <gl-avatar-labeled
        shape="circle"
        :size="32"
        :src="item.avatarUrl"
        :label="item.text"
        :sub-label="item.username"
      />
    </template>
  </gl-collapsible-listbox>
</template>
