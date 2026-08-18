<script>
import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlModal,
  GlModalDirective,
  GlIcon,
  GlPagination,
  GlTable,
  GlTooltip,
  GlTooltipDirective,
} from '@gitlab/ui';
import getBillableMembersQuery from 'ee/usage_quotas/seats/graphql/get_billable_members.query.graphql';
import dateFormat from '~/lib/dateformat';
import {
  FIELDS,
  AVATAR_SIZE,
  SORT_OPTIONS,
  REMOVE_BILLABLE_MEMBER_MODAL_ID,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX,
  DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX,
  emailNotVisibleTooltipText,
  filterUsersPlaceholder,
} from 'ee/usage_quotas/seats/constants';
import { s__, __ } from '~/locale';
import SearchAndSortBar from '~/usage_quotas/components/search_and_sort_bar/search_and_sort_bar.vue';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import * as GroupsApi from 'ee/api/groups_api';
import RemoveBillableMemberModal from './remove_billable_member_modal.vue';
import SubscriptionSeatDetails from './subscription_seat_details.vue';

export const FIVE_MINUTES_IN_MS = 1000 * 60 * 5;

export default {
  name: 'SubscriptionUserList',
  directives: {
    GlModal: GlModalDirective,
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlButton,
    GlModal,
    GlIcon,
    GlPagination,
    GlTable,
    GlTooltip,
    RemoveBillableMemberModal,
    SearchAndSortBar,
    SubscriptionSeatDetails,
  },
  inject: ['subscriptionHistoryHref', 'seatUsageExportPath', 'namespaceId'],
  props: {
    hasFreePlan: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['refetch-data'],
  data() {
    return {
      recentlyDeletedMembersIds: [],
      total: null,
      page: 1,
      search: null,
      perPage: null,
      sort: 'last_activity_on_desc',
      billableMembers: [],
      billableMemberToRemove: null,
      isRemovingBillableMember: false,
      billableMemberIdBeingRemoved: null,
    };
  },
  apollo: {
    billableMembers: {
      query: getBillableMembersQuery,
      variables() {
        return {
          namespaceId: this.namespaceId,
          page: this.page,
          search: this.search,
          sort: this.sort,
        };
      },
      update({ billableMembers }) {
        const { members, total, page, perPage } = billableMembers;

        // set total, page, and perPage for the pagination component
        this.total = total;
        this.page = page;
        this.perPage = perPage;

        // create new extensible objects from the members array, so we can use the gl-table details slot
        return members.map((member) => ({ ...member }));
      },
      error(error) {
        createAlert({
          message: s__('Billing|An error occurred while loading billable members list.'),
        });

        Sentry.captureException(error);
      },
    },
  },
  computed: {
    emptyText() {
      if (this.search?.length < 3) {
        return s__('Billing|Enter at least three characters to search.');
      }
      return s__('Billing|No users to display.');
    },
    isLoaderShown() {
      return this.$apollo.loading || this.isRemovingBillableMember;
    },
    deletedMembersKey() {
      return `${this.namespaceId}-${DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX}`;
    },
    deletedMembersExpireKey() {
      return `${this.namespaceId}-${DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX}`;
    },
    shouldShowDownloadSeatUsageHistory() {
      return !this.hasFreePlan;
    },
  },
  mounted() {
    this.recentlyDeletedMembersIds = this.getRecentlyDeletedMembersIds();
  },
  methods: {
    formatLastLoginAt(lastLogin) {
      return lastLogin ? dateFormat(lastLogin, 'yyyy-mm-dd HH:MM:ss') : __('Never');
    },
    applyFilter(searchTerm) {
      // reset pagination on applying new filter
      this.page = 1;

      this.search = searchTerm;
    },
    setSortOption(sortOption) {
      this.sort = sortOption;

      Tracking.event('usage_quota_seats', 'click', {
        label: 'billable_members_table_sort_selection',
        property: sortOption,
      });
    },
    displayRemoveMemberModal(user) {
      if (user.removable) {
        this.billableMemberToRemove = user;
      } else {
        this.$refs.cannotRemoveModal.show();
      }
    },
    hasLocalStorageExpired() {
      const expire = localStorage.getItem(this.deletedMembersExpireKey);
      if (!expire) return true;
      return Date.now() > expire;
    },
    isGroupInvite(user) {
      return user.membership_type === 'group_invite';
    },
    isProjectInvite(user) {
      return user.membership_type === 'project_invite';
    },
    isUserRemoved(user) {
      if (this.billableMemberIdBeingRemoved === user?.id) return true;

      return this.recentlyDeletedMembersIds.includes(user?.id);
    },
    isLastOwner(user) {
      return user.is_last_owner;
    },
    getRecentlyDeletedMembersIds() {
      try {
        if (this.hasLocalStorageExpired()) {
          localStorage.removeItem(this.deletedMembersKey);
          return [];
        }
        return JSON.parse(localStorage.getItem(this.deletedMembersKey) || '[]');
      } catch {
        return [];
      }
    },
    removeButtonDisabled(user) {
      return this.isUserRemoved(user) || this.isLastOwner(user);
    },
    updateDeletedMembersStorage(memberId) {
      const uniqueMembersIds = Array.from(new Set([...this.recentlyDeletedMembersIds, memberId]));
      this.recentlyDeletedMembersIds = uniqueMembersIds;

      try {
        const deleteMembersString = JSON.stringify(uniqueMembersIds);
        localStorage.setItem(this.deletedMembersExpireKey, Date.now() + FIVE_MINUTES_IN_MS);
        localStorage.setItem(this.deletedMembersKey, deleteMembersString);
      } catch (error) {
        Sentry.captureException(error);
      }
    },
    removeBillableMember(memberId) {
      this.billableMemberIdBeingRemoved = memberId;

      this.isRemovingBillableMember = true;

      return GroupsApi.removeBillableMemberFromGroup(this.namespaceId, memberId)
        .then(() => {
          this.updateDeletedMembersStorage(memberId);

          this.$apollo.queries.billableMembers.refetch();
          this.$emit('refetch-data');

          const removeBillableMemberSuccessMessage = s__(
            'Billing|User successfully scheduled for removal. This process might take some time. Refresh the page to see the changes.',
          );

          createAlert({
            message: removeBillableMemberSuccessMessage,
            variant: VARIANT_SUCCESS,
          });
        })
        .catch(() => {
          createAlert({
            message: s__('Billing|An error occurred while removing a billable member.'),
          });
        })
        .finally(() => {
          this.billableMemberIdBeingRemoved = null;
          this.isRemovingBillableMember = false;
        });
    },
  },
  i18n: {
    emailNotVisibleTooltipText,
    filterUsersPlaceholder,
  },
  avatarSize: AVATAR_SIZE,
  removeBillableMemberModalId: REMOVE_BILLABLE_MEMBER_MODAL_ID,
  cannotRemoveModalId: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID,
  cannotRemoveModalTitle: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE,
  cannotRemoveModalText: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  sortOptions: SORT_OPTIONS,
  tableFields: FIELDS,
};
</script>

<template>
  <section>
    <div class="gl-flex gl-bg-subtle gl-p-5">
      <search-and-sort-bar
        :namespace="String(namespaceId)"
        :search-input-placeholder="$options.i18n.filterUsersPlaceholder"
        :sort-options="$options.sortOptions"
        initial-sort-by="last_activity_on_desc"
        @on-filter="applyFilter"
        @on-sort="setSortOption"
      />
      <gl-button
        v-if="seatUsageExportPath"
        data-testid="export-button"
        :href="seatUsageExportPath"
        class="gl-ml-3"
      >
        {{ s__('Billing|Export list') }}
      </gl-button>
      <gl-button
        v-if="shouldShowDownloadSeatUsageHistory"
        :href="subscriptionHistoryHref"
        class="gl-ml-3"
        data-testid="subscription-seat-usage-history"
      >
        {{ __('Export seat usage history') }}
      </gl-button>
    </div>

    <gl-table
      :items="billableMembers"
      :fields="$options.tableFields"
      :busy="isLoaderShown"
      :show-empty="true"
      data-testid="subscription-users"
      :empty-text="emptyText"
    >
      <template #cell(disclosure)="{ item, toggleDetails, detailsShowing }">
        <gl-button
          variant="link"
          class="gl-h-7 gl-w-7"
          :aria-label="s__('Billing|Toggle seat details')"
          :aria-expanded="detailsShowing ? 'true' : 'false'"
          :data-testid="`toggle-seat-usage-details-${item.id}`"
          @click="toggleDetails"
        >
          <gl-icon :name="detailsShowing ? 'chevron-down' : 'chevron-right'" />
        </gl-button>
      </template>

      <template #cell(user)="{ item }">
        <div class="gl-flex">
          <gl-avatar-link target="blank" :href="item.web_url" :alt="item.name">
            <gl-avatar-labeled
              :src="item.avatar_url"
              :size="$options.avatarSize"
              :label="item.name"
              :sub-label="`@${item.username}`"
            >
              <template #meta>
                <gl-badge v-if="isGroupInvite(item)" variant="neutral">
                  {{ s__('Billing|Group invite') }}
                </gl-badge>
                <gl-badge v-if="isProjectInvite(item)" variant="neutral">
                  {{ s__('Billing|Project invite') }}
                </gl-badge>
              </template>
            </gl-avatar-labeled>
          </gl-avatar-link>
        </div>
      </template>

      <template #cell(email)="{ item }">
        <div data-testid="email">
          <span v-if="item.email" class="gl-text-default">{{ item.email }}</span>
          <span
            v-else
            v-gl-tooltip
            :title="$options.i18n.emailNotVisibleTooltipText"
            class="gl-italic"
          >
            {{ s__('Billing|Private') }}
          </span>
        </div>
      </template>

      <template #cell(lastActivityTime)="{ item }">
        <span data-testid="last_activity_on">
          {{ item.last_activity_on ? item.last_activity_on : __('Never') }}
        </span>
      </template>

      <template #cell(lastLoginAt)="{ item }">
        <span data-testid="last_login_at">
          {{ formatLastLoginAt(item.last_login_at) }}
        </span>
      </template>

      <template #cell(actions)="{ item }">
        <span :id="`remove-user-${item.id}`" class="gl-inline-block" tabindex="0">
          <gl-button
            v-gl-modal="$options.removeBillableMemberModalId"
            category="secondary"
            variant="danger"
            data-testid="remove-user"
            :disabled="removeButtonDisabled(item)"
            @click="displayRemoveMemberModal(item)"
          >
            {{ __('Remove user') }}
          </gl-button>

          <gl-tooltip
            v-if="removeButtonDisabled(item)"
            :target="`remove-user-${item.id}`"
            data-testid="remove-user-tooltip"
          >
            {{
              isLastOwner(item)
                ? s__('Billing|Cannot remove the last owner.')
                : s__('Billing|This user is scheduled for removal.')
            }}</gl-tooltip
          >
        </span>
      </template>

      <template #row-details="{ item }">
        <subscription-seat-details :seat-member-id="item.id" />
      </template>
    </gl-table>

    <gl-pagination
      v-if="page"
      v-model="page"
      :per-page="perPage"
      :total-items="total"
      align="center"
      class="gl-mt-5"
    />

    <remove-billable-member-modal
      :billable-member-to-remove="billableMemberToRemove"
      @remove-billable-member="removeBillableMember"
    />

    <gl-modal
      ref="cannotRemoveModal"
      :modal-id="$options.cannotRemoveModalId"
      :title="$options.cannotRemoveModalTitle"
      :action-primary="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: __('Okay'),
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      static
    >
      <p>
        {{ $options.cannotRemoveModalText }}
      </p>
    </gl-modal>
  </section>
</template>
<style>
.b-table-has-details > td:first-child {
  border-bottom: none;
}
.b-table-details > td {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
}
</style>
