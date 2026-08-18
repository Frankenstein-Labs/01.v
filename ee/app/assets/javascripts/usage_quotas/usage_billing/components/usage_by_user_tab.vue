<script>
import {
  GlAlert,
  GlBadge,
  GlKeysetPagination,
  GlSorting,
  GlTableLite,
  GlProgressBar,
  GlEmptyState,
  GlSkeletonLoader,
} from '@gitlab/ui';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { s__, __ } from '~/locale';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { convertToSnakeCase } from '~/lib/utils/text_utility';
import getSubscriptionUsersUsageQuery from '../graphql/get_subscription_users_usage.query.graphql';
import { PAGE_SIZE } from '../constants';
import { fillUsageValues, formatNumber } from '../utils';

/**
 * @typedef {object} Usage
 * @property { number } totalCredits
 * @property { number } creditsUsed
 * @property { number } poolCreditsUsed
 * @property { number } monthlyWaiverCreditsUsed
 * @property { number } overageCreditsUsed
 * @property { number } paidTierTrialCreditsUsed
 */

export default {
  name: 'UsageByUserTab',
  components: {
    UserAvatarLink,
    GlAlert,
    GlBadge,
    GlSorting,
    GlTableLite,
    GlProgressBar,
    GlKeysetPagination,
    GlEmptyState,
    GlSkeletonLoader,
  },
  inject: {
    userUsagePath: 'userUsagePath',
    namespacePath: {
      default: null,
    },
  },
  data() {
    return {
      isError: false,
      searchQuery: '',
      usersUsage: [],
      pageInfo: {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      },
      sortBy: 'totalCreditsUsed',
      isAscending: false,
    };
  },
  apollo: {
    usersUsage: {
      query: getSubscriptionUsersUsageQuery,
      variables() {
        return {
          // NOTE: namespacePath will be present on SaaS only, indicating a root group.
          // SM would pass null in this variable, requesting instance-level data.
          namespacePath: this.namespacePath,
          searchQuery: this.searchQuery,
          sort: this.sortKey,
          ...this.pageInfo,
        };
      },
      error(error) {
        this.isError = true;
        logError(error);
        captureException(error);
      },
      update({
        subscriptionUsage: {
          usersUsage: { users },
        },
      }) {
        return users;
      },
    },
  },
  computed: {
    hasIncludedCreditsData() {
      return this.usersList.some((user) => user.usage.creditsUsed || user.usage.totalCredits);
    },
    tableFields() {
      return [
        {
          key: 'name',
          label: __('User'),
        },
        this.hasIncludedCreditsData && {
          key: 'includedCredits',
          label: s__('UsageBilling|Included credits'),
        },
        {
          key: 'totalCreditsUsed',
          label: s__('UsageBilling|Total credits used'),
          thAlignRight: true,
          tdClass: 'gl-text-right',
        },
        {
          key: 'usageControlStatus',
          label: s__('UsageBilling|Usage control status'),
          tdAttr: { 'data-testid': 'usage-control-status-cell' },
        },
      ].filter(Boolean);
    },
    usersList() {
      const nodes = this.usersUsage.nodes ?? [];
      return nodes.map((user) => ({
        ...user,
        usage: fillUsageValues(user?.usage),
        blocked: Boolean(user?.blockedStatus?.blocked),
      }));
    },
    emptyUsersList() {
      return this.usersList.length === 0;
    },
    emptyStateDescription() {
      return this.searchQuery ? s__('UsageBilling|Edit your search and try again.') : '';
    },
    isLoadingUsers() {
      return this.$apollo.queries.usersUsage.loading;
    },
    sortKey() {
      if (!this.sortBy) return null;

      const sortBy = convertToSnakeCase(this.sortBy);
      const direction = this.isAscending ? 'asc' : 'desc';
      return `${sortBy}_${direction}`.toUpperCase();
    },
  },
  methods: {
    formatNumber,
    /** @param { Usage } usage */
    getTotalCreditsUsed(usage) {
      return (
        usage.creditsUsed +
        usage.monthlyCommitmentCreditsUsed +
        usage.monthlyWaiverCreditsUsed +
        usage.overageCreditsUsed +
        usage.paidTierTrialCreditsUsed
      );
    },
    formatIncludedCredits(includedCreditsUsed, includedTotalCredits) {
      const used = formatNumber(includedCreditsUsed);
      const total = formatNumber(includedTotalCredits);
      return `${used} / ${total}`;
    },
    getUserUsagePath(username) {
      return this.userUsagePath.replace('__USERNAME__', username);
    },
    /** @param { Usage } usage */
    getProgressBarValue(usage) {
      if (usage.totalCredits === 0) {
        return 0;
      }

      return (usage.creditsUsed / usage.totalCredits) * 100;
    },
    onNextPage(item) {
      this.pageInfo = {
        first: PAGE_SIZE,
        after: item,
        last: null,
        before: null,
      };
    },
    onPrevPage(item) {
      this.pageInfo = {
        first: null,
        after: null,
        last: PAGE_SIZE,
        before: item,
      };
    },
    onSortByChange(sortBy) {
      this.sortBy = sortBy;
      this.resetPagination();
    },
    onSortDirectionChange() {
      this.isAscending = !this.isAscending;
      this.resetPagination();
    },
    resetPagination() {
      this.pageInfo = {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      };
    },
  },
  sortOptions: [
    { value: 'name', text: __('User') },
    { value: 'totalCreditsUsed', text: s__('UsageBilling|Total credits used') },
  ],
};
</script>

<template>
  <div>
    <!--gl-search-box-by-type
      Searching is disabled until we implement https://gitlab.com/gitlab-org/gitlab/-/work_items/592966
      :aria-label="s__(`UsageBilling|Search for a user`)"
      class="gl-my-3"
      @input="onSearch"
    / -->

    <section v-if="isLoadingUsers">
      <gl-skeleton-loader v-for="i in 10" :key="i" :width="1000" :height="48">
        <rect width="200" height="16" x="10" y="16" rx="4" />
        <rect width="200" height="16" x="400" y="16" rx="4" />
        <rect width="100" height="16" x="900" y="16" rx="4" />
      </gl-skeleton-loader>
    </section>

    <gl-alert v-else-if="isError" variant="danger" class="gl-my-3">
      {{ s__('UsageBilling|An error occurred while fetching data') }}
    </gl-alert>

    <gl-empty-state
      v-else-if="emptyUsersList"
      :title="s__('UsageBilling|No users found')"
      :description="emptyStateDescription"
      class="gl-mt-6"
      illustration-name="empty-search-md"
    />

    <section v-else>
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
          :is-ascending="isAscending"
          :sort-options="$options.sortOptions"
          :sort-by="sortBy"
          block
          @sortByChange="onSortByChange"
          @sortDirectionChange="onSortDirectionChange"
        />
      </header>
      <gl-table-lite
        :items="usersList"
        :fields="tableFields"
        :busy="isLoadingUsers"
        show-empty
        stacked="md"
        class="gl-w-full [&_th]:!gl-border-none"
      >
        <template #head(totalCreditsUsed)="{ label }">
          <div class="gl-flex gl-justify-end">{{ label }}</div>
        </template>
        <template #head(usageControlStatus)="{ label }">
          <div class="gl-flex gl-justify-end">{{ label }}</div>
        </template>
        <template #cell(name)="{ item: user }">
          <div class="gl-flex gl-items-center">
            <user-avatar-link
              :username="user.name"
              :link-href="getUserUsagePath(user.username)"
              :img-alt="user.name"
              :img-src="user.avatarUrl"
              :img-size="32"
              tooltip-placement="bottom"
              class="gl-items-center gl-gap-3"
            />
          </div>
        </template>

        <template #cell(includedCredits)="{ item: user }">
          <div class="gl-flex gl-min-h-7 gl-items-center gl-gap-6">
            <span class="gl-font-weight-semibold gl-min-w-11 gl-text-gray-900">
              {{ formatIncludedCredits(user.usage.creditsUsed, user.usage.totalCredits) }}
            </span>
            <gl-progress-bar
              :value="getProgressBarValue(user.usage)"
              class="gl-h-3 gl-max-w-[160px] gl-flex-1"
            />
          </div>
        </template>

        <template #cell(totalCreditsUsed)="{ item: user }">
          <div
            class="gl-font-weight-semibold gl-flex gl-min-h-7 gl-items-center gl-justify-end gl-text-gray-900"
          >
            {{ formatNumber(getTotalCreditsUsed(user.usage)) }}
          </div>
        </template>

        <template #cell(usageControlStatus)="{ item: user }">
          <div class="gl-flex gl-justify-end">
            <gl-badge v-if="user.blocked" variant="danger">{{
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
      </gl-table-lite>

      <div class="gl-mt-5 gl-flex gl-justify-center">
        <gl-keyset-pagination v-bind="usersUsage.pageInfo" @prev="onPrevPage" @next="onNextPage" />
      </div>
    </section>
  </div>
</template>
