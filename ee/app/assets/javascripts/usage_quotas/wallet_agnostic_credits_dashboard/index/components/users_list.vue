<script>
import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlKeysetPagination,
  GlSorting,
  GlTable,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { formatNumber } from '../../../usage_billing/utils';

export default {
  name: 'UsersList',
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlKeysetPagination,
    GlSorting,
    GlTable,
  },
  props: {
    users: {
      type: Object,
      required: true,
    },
    userUsagePath: {
      type: String,
      required: false,
      default: null,
    },
    sortBy: {
      type: String,
      required: true,
    },
    sortAscending: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['next-page', 'prev-page', 'sort-change'],
  computed: {
    userNodes() {
      return this.users.nodes ?? [];
    },
  },
  methods: {
    formatNumber,
    isAutomatedFlowUser(user) {
      return user.entityType === 'non_human';
    },
    getUserUsagePath(username) {
      if (!this.userUsagePath) return null;
      return this.userUsagePath.replace('__USERNAME__', username);
    },
    onNextPage(cursor) {
      this.$emit('next-page', cursor);
    },
    onPrevPage(cursor) {
      this.$emit('prev-page', cursor);
    },
    onSortByChange(sortBy) {
      this.$emit('sort-change', { sortBy, sortAscending: this.sortAscending });
    },
    onSortDirectionChange() {
      this.$emit('sort-change', { sortBy: this.sortBy, sortAscending: !this.sortAscending });
    },
  },
  tableFields: [
    {
      key: 'user',
      label: s__('UsageBilling|User'),
    },
    {
      key: 'creditsUsed',
      label: s__('UsageBilling|Credits used'),
      thAlignRight: true,
      tdClass: 'gl-text-right',
    },
    {
      key: 'usageControlStatus',
      label: s__('UsageBilling|Usage control status'),
      thAlignRight: true,
      tdAttr: { 'data-testid': 'usage-control-status-cell' },
    },
  ],
  sortOptions: [
    { value: 'name', text: __('User') },
    { value: 'totalCreditsUsed', text: s__('UsageBilling|Total credits used') },
  ],
};
</script>

<template>
  <div>
    <header
      class="gl-border-b gl--mt-3 gl-flex gl-items-center gl-justify-between gl-bg-subtle gl-p-5"
    >
      <p class="gl-m-0">
        {{
          s__(
            'UsageBilling|Sorting by total credits used displays only users with prior credit usage.',
          )
        }}
      </p>
      <gl-sorting
        :is-ascending="sortAscending"
        :sort-options="$options.sortOptions"
        :sort-by="sortBy"
        block
        @sortByChange="onSortByChange"
        @sortDirectionChange="onSortDirectionChange"
      />
    </header>
    <gl-table
      :items="userNodes"
      :fields="$options.tableFields"
      show-empty
      stacked="md"
      class="gl-w-full"
      borderless
    >
      <template #head(creditsUsed)="{ label }">
        <div class="gl-flex gl-justify-end">{{ label }}</div>
      </template>

      <template #head(usageControlStatus)="{ label }">
        <div class="gl-flex gl-justify-end">{{ label }}</div>
      </template>

      <template #cell(user)="{ item: user }">
        <div class="gl-flex gl-items-center gl-gap-3">
          <gl-avatar-link :href="getUserUsagePath(user.username)" :alt="user.name">
            <gl-avatar-labeled
              :src="user.avatarUrl"
              :size="32"
              :label="user.name"
              :sub-label="`@${user.username}`"
            />
          </gl-avatar-link>
          <gl-badge
            v-if="isAutomatedFlowUser(user)"
            variant="info"
            data-testid="automated-flow-badge"
          >
            {{ s__('UsageBilling|Automated flow') }}
          </gl-badge>
        </div>
      </template>

      <template #cell(creditsUsed)="{ item: user }">
        {{ formatNumber(user.usage?.totalCreditsUsed) }}
      </template>

      <template #cell(usageControlStatus)="{ item: user }">
        <div class="gl-flex gl-justify-end">
          <gl-badge v-if="user.blockedStatus?.blocked" variant="danger">{{
            s__('UsageBilling|Blocked usage')
          }}</gl-badge>
          <gl-badge v-else variant="neutral">{{ s__('UsageBilling|Regular usage') }}</gl-badge>
        </div>
      </template>

      <template #empty>
        <div class="gl-py-6 gl-text-center">
          <p class="gl-mb-0 gl-text-subtle">{{ s__('UsageBilling|No user data available') }}</p>
        </div>
      </template>
    </gl-table>

    <div class="gl-mt-5 gl-flex gl-justify-center">
      <gl-keyset-pagination v-bind="users.pageInfo" @prev="onPrevPage" @next="onNextPage" />
    </div>
  </div>
</template>
