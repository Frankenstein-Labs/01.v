<script>
import { GlLoadingIcon, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import getUsersByUserIdsOrUsernames from 'ee/graphql_shared/queries/get_users_by_user_ids_or_usernames.query.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER } from '~/graphql_shared/constants';

export default {
  i18n: {
    enabledTooltip: s__('SecurityOrchestration|Users can skip pipelines'),
    disabledTooltip: s__("SecurityOrchestration|Users can't skip pipelines"),
    userExceptionsText: s__('SecurityOrchestration|Except for following users:'),
  },
  name: 'SkipCiConfiguration',
  components: {
    GlIcon,
    GlLoadingIcon,
  },
  apollo: {
    users: {
      query: getUsersByUserIdsOrUsernames,
      variables() {
        return {
          user_ids: this.userIds,
        };
      },
      update(data) {
        return data.users.nodes || [];
      },
      skip() {
        return this.userIds.length === 0 || this.skipCi;
      },
    },
  },
  props: {
    configuration: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  data() {
    return {
      users: [],
    };
  },
  computed: {
    loading() {
      return this.$apollo.queries.users.loading;
    },
    skipCi() {
      return this.configuration?.allowed;
    },
    userIds() {
      const { allowlist: { users = [] } = {} } = this.configuration || {};
      return users.map(({ id }) => convertToGraphQLId(TYPENAME_USER, id));
    },
    label() {
      return this.skipCi ? this.$options.i18n.enabledTooltip : this.$options.i18n.disabledTooltip;
    },
    variant() {
      return this.skipCi ? 'success' : 'disabled';
    },
    name() {
      return this.skipCi ? 'check-circle-filled' : 'check-circle-dashed';
    },
    cssClass() {
      return this.skipCi ? 'gl-text-success' : 'gl-text-disabled';
    },
    showUserList() {
      return !this.skipCi && this.userIds?.length > 0;
    },
  },
};
</script>

<template>
  <div>
    <div>
      <gl-icon :aria-label="label" :name="name" :variant="variant" />
      <span data-testid="status-label" class="gl-m-0 gl-ml-1" :class="cssClass">
        {{ label }}
      </span>
    </div>
    <div v-if="showUserList">
      <gl-loading-icon v-if="loading" />
      <div v-else class="gl-mt-4">
        <p class="gl-mb-2">{{ $options.i18n.userExceptionsText }}</p>
        <ul data-testid="user-list">
          <li v-for="user in users" :key="user.id">
            {{ user.name }}
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>
