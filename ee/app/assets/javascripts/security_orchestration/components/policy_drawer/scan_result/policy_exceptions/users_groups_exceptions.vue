<script>
import { GlAccordion, GlAccordionItem, GlSprintf, GlTruncate } from '@gitlab/ui';
import { get } from 'lodash-es';
import { s__, __, sprintf } from '~/locale';
import { isProject } from 'ee/security_orchestration/components/utils';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_USER } from '~/graphql_shared/constants';
import PolicyExceptionsLoader from './policy_exceptions_loader.vue';

export default {
  i18n: {
    groupTitle: __('Groups'),
    userTitle: __('Users'),
    loadingLabelGroups: __('Loading groups'),
    loadingLabelUsers: __('Loading users'),
  },
  name: 'UsersGroupsExceptions',
  components: {
    GlAccordion,
    GlAccordionItem,
    GlSprintf,
    GlTruncate,
    PolicyExceptionsLoader,
  },
  inject: ['namespacePath', 'namespaceType'],
  props: {
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
    users: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      allGroups: [],
      allUsers: [],
      loadingUsers: false,
      loadingGroups: false,
      loadingUsersFailed: false,
      loadingGroupsFailed: false,
    };
  },
  computed: {
    groupsIds() {
      return (this.groups || []).map(({ id }) => id).filter(Boolean);
    },
    groupsIdsFullFormat() {
      return this.groupsIds.map((id) => convertToGraphQLId(TYPENAME_GROUP, String(id)));
    },
    usersIdsFullFormat() {
      return this.usersIds.map((id) => convertToGraphQLId(TYPENAME_USER, String(id)));
    },
    usersIds() {
      return (this.users || []).map(({ id }) => id).filter(Boolean);
    },
    hasGroupsLoaded() {
      return this.allGroups?.length > 0;
    },
    hasUsersLoaded() {
      return this.allUsers?.length > 0;
    },
    totalCount() {
      return (this.users?.length || 0) + (this.groups?.length || 0);
    },
    title() {
      return sprintf(s__('SecurityOrchestration|Users and Groups (%{count})'), {
        count: this.totalCount,
      });
    },
    selectedGroups() {
      return this.allGroups?.filter(({ id }) => this.groupsIds.includes(getIdFromGraphQLId(id)));
    },
    selectedUsers() {
      return (
        this.allUsers?.filter(({ user }) => this.usersIds.includes(getIdFromGraphQLId(user.id))) ||
        []
      );
    },
    hasSelectedUsers() {
      return this.users?.length > 0;
    },
    hasSelectedGroups() {
      return this.groups?.length > 0;
    },
  },
  methods: {
    renderFullUserName(user = {}) {
      return sprintf(__('%{name} %{codeStart}%{username}%{codeEnd}'), {
        name: user.name,
        username: user.username,
      });
    },
    async loadGroups() {
      this.loadingGroups = true;
      this.loadingGroupsFailed = false;

      try {
        const { data } = await this.$apollo.query({
          query: getGroups,
          variables: {
            ids: this.groupsIdsFullFormat,
            search: '',
          },
        });

        this.allGroups = get(data, 'groups.nodes', []);
      } catch {
        this.loadingGroupsFailed = true;
        this.allGroups = [];
      } finally {
        this.loadingGroups = false;
      }
    },
    async loadUsers() {
      this.loadingUsers = true;
      this.loadingUsersFailed = false;

      try {
        const query = isProject(this.namespaceType) ? searchProjectMembers : searchGroupMembers;

        const { data } = await this.$apollo.query({
          query,
          variables: {
            fullPath: this.namespacePath,
            search: '',
            ids: this.usersIdsFullFormat,
          },
        });

        this.allUsers = isProject(this.namespaceType)
          ? get(data, 'project.projectMembers.nodes', [])
          : get(data, 'namespace.users.nodes', []);
      } catch {
        this.loadingUsersFailed = true;
        this.allUsers = [];
      } finally {
        this.loadingUsers = false;
      }
    },
    toggleAccordion(opened) {
      if (!opened) {
        return;
      }

      if (!this.hasUsersLoaded) {
        this.loadUsers();
      }

      if (!this.hasGroupsLoaded) {
        this.loadGroups();
      }
    },
  },
};
</script>

<template>
  <gl-accordion :header-level="3">
    <gl-accordion-item :title="title" @input="toggleAccordion">
      <policy-exceptions-loader
        v-if="loadingUsers"
        class="gl-mb-2"
        :label="$options.i18n.loadingLabelUsers"
      />
      <div v-else>
        <div v-if="hasSelectedUsers">
          <h5 class="gl-mb-2" data-testid="user-header">{{ $options.i18n.userTitle }}</h5>

          <ul v-if="loadingUsersFailed" class="gl-mb-4 gl-list-none gl-pl-4">
            <li v-for="id in usersIds" :key="id" data-testid="user-item-fallback">
              {{ __('id:') }} {{ id }}
            </li>
          </ul>

          <ul v-else class="gl-mb-4 gl-list-none gl-pl-4">
            <li
              v-for="item in selectedUsers"
              :key="item.user.id"
              class="gl-mb-3"
              data-testid="user-item"
            >
              <gl-sprintf :message="renderFullUserName(item.user)">
                <template #code="{ content }">
                  <code>{{ content }}</code>
                </template>
              </gl-sprintf>
            </li>
          </ul>
        </div>
      </div>

      <policy-exceptions-loader v-if="loadingGroups" :label="$options.i18n.loadingLabelGroups" />
      <div v-else>
        <div v-if="hasSelectedGroups">
          <h5 class="gl-mb-2" data-testid="group-header">{{ $options.i18n.groupTitle }}</h5>

          <ul v-if="loadingGroupsFailed" class="gl-mb-4 gl-list-none gl-pl-4">
            <li v-for="id in groupsIds" :key="id" data-testid="group-item-fallback">
              {{ __('id:') }} {{ id }}
            </li>
          </ul>

          <ul v-else class="gl-mb-4 gl-list-none gl-pl-4">
            <li
              v-for="group in selectedGroups"
              :key="group.id"
              class="gl-mb-3"
              data-testid="group-item"
            >
              <gl-truncate
                v-if="group.fullName"
                :text="group.fullName"
                position="middle"
                with-tooltip
              />
            </li>
          </ul>
        </div>
      </div>
    </gl-accordion-item>
  </gl-accordion>
</template>
