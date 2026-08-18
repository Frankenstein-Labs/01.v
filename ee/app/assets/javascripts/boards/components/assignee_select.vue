<script>
import { GlButton } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import usersAutocompleteQuery from '~/graphql_shared/queries/users_autocomplete.query.graphql';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import DropdownWidget from '~/vue_shared/components/dropdown/dropdown_widget/dropdown_widget.vue';
import UserAvatarImage from '~/vue_shared/components/user_avatar/user_avatar_image.vue';
import { setError } from '~/boards/graphql/cache_updates';

import { AssigneesPreset, ANY_ASSIGNEE, BoardType } from '../constants';

export default {
  name: 'AssigneeSelect',
  AssigneesPreset,
  components: {
    UserAvatarImage,
    DropdownWidget,
    GlButton,
  },
  inject: ['fullPath', 'isProjectBoard'],
  props: {
    board: {
      type: Object,
      required: true,
    },
    canEdit: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['set-assignee'],
  data() {
    return {
      search: '',
      searchUsers: [],
      selected: this.board.assignee,
      isEditing: false,
      isDropdownShowing: false,
    };
  },
  apollo: {
    searchUsers: {
      query() {
        return usersAutocompleteQuery;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          search: this.search,
          isProject: this.isProjectBoard,
        };
      },
      skip() {
        return !this.isEditing;
      },
      update(data) {
        const namespace = this.isProjectBoard ? BoardType.project : BoardType.group;

        return data[namespace]?.autocompleteUsers;
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      error(error) {
        setError({ error, message: this.$options.i18n.errorSearchingUsers });
      },
    },
  },
  computed: {
    anyAssignee() {
      return this.selected.name === ANY_ASSIGNEE.name;
    },
    isLoading() {
      return this.$apollo.queries.searchUsers.loading;
    },
    users() {
      const filteredUsers = this.searchUsers.filter(
        (user) => user.name.includes(this.search) || user.username.includes(this.search),
      );

      // TODO this de-duplication is temporary (BE fix required)
      // https://gitlab.com/gitlab-org/gitlab/-/issues/327822
      return filteredUsers
        .concat(this.searchUsers)
        .reduce(
          (acc, current) => (acc.some((user) => current.id === user.id) ? acc : [...acc, current]),
          [],
        );
    },
  },
  created() {
    if (isEmpty(this.board.assignee)) {
      this.selected = ANY_ASSIGNEE;
    }
  },
  methods: {
    selectAssignee(user) {
      this.selected = user;
      this.toggleEdit();
      this.$emit('set-assignee', user?.id || null);
    },
    toggleEdit() {
      if (!this.isEditing && !this.isDropdownShowing) {
        this.isEditing = true;
        this.showDropdown();
      } else {
        this.isEditing = false;
        this.isDropdownShowing = false;
      }
    },
    showDropdown() {
      this.$refs.editDropdown.showDropdown();
      this.isDropdownShowing = true;
    },
    hideDropdown() {
      this.isEditing = false;
    },
    setSearch(search) {
      this.search = search;
    },
  },
  i18n: {
    label: s__('BoardScope|Assignee'),
    anyAssignee: s__('BoardScope|Any assignee'),
    selectAssignee: s__('BoardScope|Select assignee'),
    errorSearchingUsers: s__(
      'BoardScope|An error occurred while searching for users, please try again.',
    ),
    edit: s__('BoardScope|Edit'),
  },
};
</script>

<template>
  <div class="block assignee">
    <div class="title gl-mb-3">
      {{ $options.i18n.label }}
      <gl-button
        v-if="canEdit"
        category="tertiary"
        size="small"
        class="edit-link gl-float-right"
        @click="toggleEdit"
      >
        {{ $options.i18n.edit }}
      </gl-button>
    </div>
    <div v-if="!isEditing" data-testid="selected-assignee">
      <div v-if="!anyAssignee" class="gl-flex gl-items-center gl-gap-3">
        <user-avatar-image :img-src="selected.avatarUrl || selected.avatar_url" :size="32" />
        <div>
          <div class="gl-font-bold">{{ selected.name }}</div>
          <div>@{{ selected.username }}</div>
        </div>
      </div>
      <div v-else class="gl-text-subtle">{{ $options.i18n.anyAssignee }}</div>
    </div>

    <dropdown-widget
      v-show="isEditing"
      ref="editDropdown"
      :select-text="$options.i18n.selectAssignee"
      :preset-options="$options.AssigneesPreset"
      :options="users"
      :is-loading="isLoading"
      :selected="selected"
      :search-term="search"
      @hide="hideDropdown"
      @set-option="selectAssignee"
      @set-search="setSearch"
    >
      <template #preset-item="{ item }">
        {{ item.name }}
      </template>
      <template #item="{ item }">
        {{ item.name }}
      </template>
    </dropdown-widget>
  </div>
</template>
