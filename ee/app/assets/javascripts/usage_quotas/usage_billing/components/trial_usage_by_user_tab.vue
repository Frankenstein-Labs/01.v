<script>
import { GlAlert, GlKeysetPagination, GlTableLite, GlProgressBar } from '@gitlab/ui';
import UserAvatarLink from '~/vue_shared/components/user_avatar/user_avatar_link.vue';
import { s__, __ } from '~/locale';
import { logError } from '~/lib/logger';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import getTrialUsersUsageQuery from '../graphql/get_trial_users_usage.query.graphql';
import { PAGE_SIZE } from '../constants';
import { fillUsageValues, formatNumber } from '../utils';

export default {
  name: 'TrialUsageByUserTab',
  components: {
    UserAvatarLink,
    GlAlert,
    GlTableLite,
    GlProgressBar,
    GlKeysetPagination,
  },
  inject: {
    namespacePath: {
      default: null,
    },
  },
  data() {
    return {
      isError: false,
      usersUsage: null,
      pageInfo: {
        after: null,
        before: null,
        first: PAGE_SIZE,
        last: null,
      },
    };
  },
  apollo: {
    usersUsage: {
      query: getTrialUsersUsageQuery,
      variables() {
        return {
          namespacePath: this.namespacePath,
          first: this.pageInfo.first,
          last: this.pageInfo.last,
          after: this.pageInfo.after,
          before: this.pageInfo.before,
        };
      },
      error(error) {
        this.isError = true;
        logError(error);
        captureException(error);
      },
      update(data) {
        return data.trialUsage.usersUsage;
      },
    },
  },
  computed: {
    usersList() {
      if (!this.usersUsage?.users?.nodes) {
        return [];
      }

      return this.usersUsage.users.nodes.map((user) => ({
        ...user,
        usage: fillUsageValues(user?.usage),
      }));
    },
  },
  methods: {
    formatNumber,
    getTotalCreditsUsed(usage) {
      return usage.creditsUsed;
    },
    formatIncludedCredits(creditsUsed, totalCredits) {
      const used = formatNumber(creditsUsed);
      const total = formatNumber(totalCredits);
      return `${used} / ${total}`;
    },
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
  },
  tableFields: [
    {
      key: 'user',
      label: __('User'),
    },
    {
      key: 'includedCredits',
      label: s__('UsageBilling|Included credits'),
    },
    {
      key: 'totalCreditsUsed',
      label: s__('UsageBilling|Total credits used'),
      thAlignRight: true,
      tdClass: 'gl-text-right',
    },
  ],
};
</script>

<template>
  <section v-if="$apollo.queries.usersUsage.loading">
    <div class="gl-my-3 gl-grid gl-grid-cols-1 gl-gap-5 gl-py-5 @lg/panel:gl-grid-cols-3">
      <div class="gl-animate-skeleton-loader gl-h-11 gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-11 gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-11 gl-rounded-base"></div>
    </div>

    <div class="gl-flex gl-flex-col gl-gap-3">
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
      <div class="gl-animate-skeleton-loader gl-h-5 !gl-max-w-full gl-rounded-base"></div>
    </div>
  </section>

  <gl-alert v-else-if="isError" variant="danger" class="gl-my-3">
    {{ s__('UsageBilling|An error occurred while fetching data') }}
  </gl-alert>

  <section v-else>
    <gl-table-lite
      :items="usersList"
      :fields="$options.tableFields"
      :busy="false"
      show-empty
      stacked="md"
      class="gl-w-full [&_th]:!gl-border-none"
    >
      <template #head(totalCreditsUsed)="{ label }">
        <div class="gl-flex gl-justify-end">{{ label }}</div>
      </template>
      <template #cell(user)="{ item: user }">
        <div class="gl-flex gl-items-center">
          <user-avatar-link
            :username="user.name"
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

      <template #empty>
        <div class="gl-py-6 gl-text-center">
          <p class="gl-mb-0 gl-text-subtle">{{ s__('UsageBilling|No user data available') }}</p>
        </div>
      </template>
    </gl-table-lite>

    <div class="gl-mt-5 gl-flex gl-justify-center">
      <gl-keyset-pagination
        v-if="usersUsage && usersUsage.users && usersUsage.users.pageInfo"
        v-bind="usersUsage.users.pageInfo"
        @prev="onPrevPage"
        @next="onNextPage"
      />
    </div>
  </section>
</template>
