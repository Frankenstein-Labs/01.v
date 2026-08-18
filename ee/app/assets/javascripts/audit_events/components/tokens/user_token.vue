<script>
import { getUsers } from '~/rest_api';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { parseUsername, displayUsername, isValidUsername } from '../../token_utils';
import AuditFilterToken from './shared/audit_filter_token.vue';

export default {
  name: 'UserTokenEE',
  components: {
    AuditFilterToken,
  },
  mixins: [glListenersMixin],
  inheritAttrs: false,
  tokenMethods: {
    fetchItem(term) {
      const username = parseUsername(term);
      return getUsers('', { username, per_page: 1 }).then((res) => res.data[0]);
    },
    fetchSuggestions(term) {
      return getUsers(parseUsername(term)).then((res) => res.data);
    },
    getItemName({ name }) {
      return name;
    },
    getSuggestionValue({ username }) {
      return displayUsername(username);
    },
    isValidIdentifier(username) {
      return isValidUsername(username);
    },
    findActiveItem(suggestions, username) {
      return suggestions.find((u) => u.username === parseUsername(username));
    },
  },
};
</script>

<template>
  <audit-filter-token v-bind="{ ...$attrs, ...$options.tokenMethods }" v-on="glListeners()">
    <template #suggestion="{ item: user }">
      <p class="!gl-m-0">{{ user.name }}</p>
      <p class="!gl-m-0">@{{ user.username }}</p>
    </template>
  </audit-filter-token>
</template>
