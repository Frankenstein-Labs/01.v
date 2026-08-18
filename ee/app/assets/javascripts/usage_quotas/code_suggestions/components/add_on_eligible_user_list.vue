<script>
import {
  GlAlert,
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlFormCheckbox,
  GlSkeletonLoader,
  GlTable,
  GlTooltipDirective,
  GlKeysetPagination,
  GlSprintf,
} from '@gitlab/ui';
import { pick, escape } from 'lodash-es';
import { __, s__, n__, sprintf, createListFormat } from '~/locale';
import { DEFAULT_PER_PAGE } from '~/api';
import SafeHtml from '~/vue_shared/directives/safe_html';
import {
  ADD_ON_ERROR_DICTIONARY,
  CANNOT_BULK_ASSIGN_ADDON_ERROR_CODE,
  CANNOT_BULK_UNASSIGN_ADDON_ERROR_CODE,
  NO_ASSIGNMENTS_FOUND_ERROR_CODE,
  NO_SEATS_AVAILABLE_ERROR_CODE,
  NOT_ENOUGH_SEATS_ERROR_CODE,
} from 'ee/usage_quotas/error_constants';
import PageSizeSelector from '~/vue_shared/components/page_size_selector.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DUO_IDENTIFIERS } from 'ee/constants/duo';
import {
  DUO_ADD_ONS,
  addOnEligibleUserListTableFields,
  ASSIGN_SEATS_BULK_ACTION,
  UNASSIGN_SEATS_BULK_ACTION,
} from 'ee/usage_quotas/code_suggestions/constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import { scrollToElement } from '~/lib/utils/scroll_utils';
import { isKnownErrorCode } from '~/lib/utils/error_utils';
import { InternalEvents } from '~/tracking';
import CodeSuggestionsAddonAssignment from 'ee/usage_quotas/code_suggestions/components/code_suggestions_addon_assignment.vue';
import AddOnBulkActionConfirmationModal from 'ee/usage_quotas/code_suggestions/components/add_on_bulk_action_confirmation_modal.vue';
import userAddOnAssignmentBulkCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_bulk_create.mutation.graphql';
import userAddOnAssignmentBulkRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_bulk_remove.mutation.graphql';
import { PROMO_URL } from '~/constants';
import { addSeatsText } from 'ee/usage_quotas/seats/constants';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'AddOnEligibleUserList',
  links: {
    sales: `${PROMO_URL}/solutions/code-suggestions/sales/`,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  components: {
    AddOnBulkActionConfirmationModal,
    CodeSuggestionsAddonAssignment,
    ErrorAlert,
    GlAlert,
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlButton,
    GlFormCheckbox,
    GlKeysetPagination,
    GlSkeletonLoader,
    GlTable,
    PageSizeSelector,
    HelpPageLink,
    GlSprintf,
  },
  mixins: [trackingMixin],
  inject: {
    addDuoProHref: { default: null },
    groupId: { default: null },
    isBulkAddOnAssignmentEnabled: { default: false },
  },
  props: {
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    users: {
      type: Array,
      required: false,
      default: () => [],
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    pageInfo: {
      type: Object,
      required: false,
      default: () => {},
    },
    pageSize: {
      type: Number,
      required: false,
      default: DEFAULT_PER_PAGE,
    },
    search: {
      type: String,
      required: false,
      default: '',
    },
    activeDuoTier: {
      type: String,
      required: true,
      validator: (val) => DUO_IDENTIFIERS.includes(val),
    },
    hideAddButtonSeatOnErrorMessage: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['next', 'page-size-change', 'prev'],
  i18n: {
    addSeatsText,
    contactSalesText: __('Contact sales'),
  },
  data() {
    return {
      error: undefined,
      selectedUsers: [],
      invalidUsers: [],
      bulkAction: undefined,
      successMessage: undefined,
      warningMessage: undefined,
      isBulkActionInProgress: false,
      isConfirmationModalVisible: false,
    };
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  assignSeatsBulkAction: ASSIGN_SEATS_BULK_ACTION,
  unassignSeatsBulkAction: UNASSIGN_SEATS_BULK_ACTION,
  avatarSize: 32,
  computed: {
    hasMaxRoleField() {
      return this.tableItems?.some(({ maxRole }) => maxRole);
    },
    showPagination() {
      if (this.isLoading || !this.pageInfo) {
        return false;
      }
      const { hasNextPage, hasPreviousPage } = this.pageInfo;
      return hasNextPage || hasPreviousPage;
    },
    emptyText() {
      if (this.search?.length < 3) {
        return s__('Billing|Enter at least three characters to search.');
      }
      return s__('Billing|No users to display.');
    },
    duoAddOn() {
      return DUO_ADD_ONS[this.activeDuoTier];
    },
    tableFieldsConfiguration() {
      let fieldConfig = [
        'user',
        // eslint-disable-next-line @gitlab/require-i18n-strings
        `${this.duoAddOn}Wide`,
        'emailWide',
        'lastActivityTime',
        'lastDuoActivityTime',
      ];

      if (this.hasMaxRoleField) {
        fieldConfig = [
          'user',
          this.duoAddOn,
          'email',
          'maxRole',
          'lastActivityTime',
          'lastDuoActivityTime',
        ];
      }

      if (this.isBulkAddOnAssignmentEnabled) {
        fieldConfig = ['checkbox', ...fieldConfig];
      }

      return fieldConfig;
    },
    tableFields() {
      return Object.values(pick(addOnEligibleUserListTableFields, this.tableFieldsConfiguration));
    },
    tableItems() {
      return this.users.map((node) => ({
        ...node,
        usernameWithHandle: `@${node?.username}`,
        addOnAssignments: node?.addOnAssignments?.nodes,
      }));
    },
    isSelectAllUsersChecked() {
      return !this.isLoading && this.users.length === this.selectedUsers.length;
    },
    isSelectAllUsersIndeterminate() {
      return this.isAnyUserSelected && !this.isSelectAllUsersChecked;
    },
    isAnyUserSelected() {
      return Boolean(this.selectedUsers.length);
    },
    pluralisedSelectedUsers() {
      return sprintf(
        n__(
          'Billing|%{value} user selected',
          'Billing|%{value} users selected',
          this.selectedUsers.length,
        ),
        { value: `<strong>${escape(this.selectedUsers.length)}</strong>` },
        false,
      );
    },
    isBulkActionToAssignSeats() {
      return this.bulkAction === ASSIGN_SEATS_BULK_ACTION;
    },
    errorAlertPrimaryButtonText() {
      const isErrorKnown =
        this.error === NO_SEATS_AVAILABLE_ERROR_CODE || this.error === NOT_ENOUGH_SEATS_ERROR_CODE;

      if (this.hideAddButtonSeatOnErrorMessage || !isErrorKnown) {
        return '';
      }

      return this.$options.i18n.addSeatsText;
    },
    toSentenceInvalidUsers() {
      const names = this.invalidUsers.map((u) => u.name);
      return createListFormat().format(names);
    },
  },
  methods: {
    nextPage() {
      // Retaining user selection on page navigation will be carried out in
      // https://gitlab.com/gitlab-org/gitlab/-/issues/443401
      this.unselectAllUsers();
      this.$emit('next', this.pageInfo.endCursor);
    },
    prevPage() {
      // Retaining user selection on page navigation will be carried out in
      // https://gitlab.com/gitlab-org/gitlab/-/issues/443401
      this.unselectAllUsers();
      this.$emit('prev', this.pageInfo.startCursor);
    },
    onPageSizeChange(size) {
      this.$emit('page-size-change', size);
    },
    handleError(error) {
      this.error = error;
      this.scrollToTop();
    },
    scrollToTop() {
      scrollToElement(this.$el);
    },
    isUserSelected(item) {
      return this.selectedUsers.includes(item.id);
    },
    handleUserSelection(user, value) {
      if (value) {
        this.selectedUsers.push(user.id);
      } else {
        this.selectedUsers = this.selectedUsers.filter((id) => id !== user.id);
      }
    },
    handleSelectAllUsers(value) {
      if (value) {
        this.selectedUsers = this.users.map((user) => user.id);
      } else {
        this.unselectAllUsers();
      }
    },
    unselectAllUsers() {
      this.selectedUsers = [];
    },
    showConfirmationModal(bulkAction) {
      this.isConfirmationModalVisible = true;
      this.bulkAction = bulkAction;
    },
    handleCancelBulkAction() {
      this.isConfirmationModalVisible = false;
      this.bulkAction = undefined;
    },
    clearAlerts() {
      this.error = undefined;
      this.successMessage = undefined;
      this.warningMessage = undefined;
    },
    async assignSeats() {
      this.clearAlerts();
      this.isBulkActionInProgress = true;

      try {
        const {
          data: { userAddOnAssignmentBulkCreate },
        } = await this.$apollo.mutate({
          mutation: userAddOnAssignmentBulkCreateMutation,
          variables: {
            userIds: this.selectedUsers,
            addOnPurchaseId: this.addOnPurchaseId,
          },
        });

        const errors = userAddOnAssignmentBulkCreate?.errors || [];

        if (errors.length) {
          this.handleBulkActionError(errors[0]);
        } else {
          const processedUserIds =
            userAddOnAssignmentBulkCreate.users?.nodes.map((user) => user.id) || [];
          this.handleBulkActionSuccess(processedUserIds);
          this.trackEvent('bulk_enable_gitlab_duo_pro_for_seats');
        }
      } catch (e) {
        this.handleBulkActionError(e);
        Sentry.captureException(e);
      } finally {
        this.resetBulkAction();
      }
    },
    async unassignSeats() {
      this.clearAlerts();
      this.isBulkActionInProgress = true;

      try {
        const {
          data: { userAddOnAssignmentBulkRemove },
        } = await this.$apollo.mutate({
          mutation: userAddOnAssignmentBulkRemoveMutation,
          variables: {
            userIds: this.selectedUsers,
            addOnPurchaseId: this.addOnPurchaseId,
          },
        });

        const errors = userAddOnAssignmentBulkRemove?.errors || [];

        if (errors.length) {
          const error = errors[0];
          if (error === NO_ASSIGNMENTS_FOUND_ERROR_CODE) {
            // NO_ASSIGNMENTS_FOUND is returned when none of the users provided
            // have add-on assignment - we consider this a success on the UI
            // as customer is trying to unassign add-on to users who already have
            // no assignment therefore not raising an error for this scenario
            this.handleBulkActionSuccess();
            return;
          }
          this.handleBulkActionError(error);
        } else {
          this.handleBulkActionSuccess();
          this.trackEvent('bulk_disable_gitlab_duo_pro_for_seats');
        }
      } catch (e) {
        this.handleBulkActionError(e);
        Sentry.captureException(e);
      } finally {
        this.resetBulkAction();
      }
    },
    handleBulkActionSuccess(processedUserIds = []) {
      if (this.isBulkActionToAssignSeats) {
        const processedSet = new Set(processedUserIds);
        const invalidUserIds = this.selectedUsers.filter((id) => !processedSet.has(id));
        this.invalidUsers = this.users.filter((user) => invalidUserIds.includes(user.id));

        if (!this.invalidUsers.length) {
          this.successMessage = n__(
            'Billing|%d user has been successfully assigned a seat.',
            'Billing|%d users have been successfully assigned seats.',
            processedUserIds.length,
          );
        } else {
          this.warningMessage = n__(
            'Billing|%d user has been assigned a seat.',
            'Billing|%d users have been assigned seats.',
            processedUserIds.length,
          );
        }
      } else {
        this.successMessage = n__(
          'Billing|%d user has been successfully unassigned a seat.',
          'Billing|%d users have been successfully unassigned a seat.',
          this.selectedUsers.length,
        );
      }
      this.unselectAllUsers();
    },
    handleBulkActionError(error) {
      let bulkActionError;

      if (isKnownErrorCode(error, ADD_ON_ERROR_DICTIONARY)) {
        bulkActionError = error;
      } else if (this.isBulkActionToAssignSeats) {
        bulkActionError = CANNOT_BULK_ASSIGN_ADDON_ERROR_CODE;
      } else {
        bulkActionError = CANNOT_BULK_UNASSIGN_ADDON_ERROR_CODE;
      }

      this.handleError(bulkActionError);
    },
    resetBulkAction() {
      this.bulkAction = undefined;
      this.isBulkActionInProgress = false;
      this.isConfirmationModalVisible = false;
    },
  },
};
</script>

<template>
  <section>
    <slot name="search-and-sort-bar"> </slot>
    <slot name="error-alert"></slot>
    <error-alert
      v-if="error"
      class="gl-mb-5"
      data-testid="error-alert"
      :error="error"
      :error-dictionary="$options.addOnErrorDictionary"
      :dismissible="true"
      :primary-button-link="addDuoProHref"
      :primary-button-text="errorAlertPrimaryButtonText"
      :secondary-button-link="$options.links.sales"
      :secondary-button-text="$options.i18n.contactSalesText"
      @dismiss="error = undefined"
    />
    <gl-alert
      v-if="successMessage"
      class="gl-mb-5"
      data-testid="success-alert"
      variant="success"
      :dismissible="true"
      @dismiss="successMessage = undefined"
    >
      {{ successMessage }}
    </gl-alert>
    <gl-alert
      v-if="warningMessage"
      class="gl-mb-5"
      data-testid="warning-alert"
      variant="warning"
      :dismissible="true"
      @dismiss="warningMessage = undefined"
    >
      {{ warningMessage }}
      <gl-sprintf
        :message="
          n__(
            'Billing|%{users} could not be assigned a seat because they are not %{linkStart}eligible%{linkEnd}.',
            'Billing|%{users} could not be assigned seats because they are not %{linkStart}eligible%{linkEnd}.',
            invalidUsers.length,
          )
        "
      >
        <template #users>
          {{ toSentenceInvalidUsers }}
        </template>
        <template #link="{ content }">
          <help-page-link
            href="subscriptions/subscription-add-ons.md#assign-gitlab-duo-seats"
            target="_blank"
            >{{ content }}</help-page-link
          >
        </template>
      </gl-sprintf>
    </gl-alert>
    <div
      v-if="isAnyUserSelected"
      class="gl-mt-5 gl-flex gl-items-center gl-justify-between gl-bg-subtle gl-p-5"
    >
      <span v-safe-html="pluralisedSelectedUsers" data-testid="selected-users-summary"></span>
      <div class="gl-flex gl-gap-3">
        <gl-button
          data-testid="unassign-seats-button"
          variant="danger"
          category="secondary"
          @click="showConfirmationModal($options.unassignSeatsBulkAction)"
          >{{ s__('Billing|Remove seat') }}</gl-button
        >
        <gl-button
          data-testid="assign-seats-button"
          variant="confirm"
          category="primary"
          @click="showConfirmationModal($options.assignSeatsBulkAction)"
          >{{ s__('Billing|Assign seat') }}</gl-button
        >
      </div>
    </div>
    <gl-table
      :items="tableItems"
      :fields="tableFields"
      :busy="isLoading"
      :show-empty="true"
      :empty-text="emptyText"
      primary-key="id"
      data-testid="add-on-eligible-users-table"
    >
      <template #table-busy>
        <div class="-gl-ml-4 gl-pt-3">
          <gl-skeleton-loader>
            <rect x="0" y="0" width="60" height="3" rx="1" />
            <rect x="126" y="0" width="60" height="3" rx="1" />
            <rect x="207" y="0" width="60" height="3" rx="1" />
            <rect x="338" y="0" width="60" height="3" rx="1" />
          </gl-skeleton-loader>
        </div>
      </template>
      <template #head(checkbox)>
        <gl-form-checkbox
          v-if="isBulkAddOnAssignmentEnabled"
          class="gl-min-h-5"
          :checked="isSelectAllUsersChecked"
          :indeterminate="isSelectAllUsersIndeterminate"
          data-testid="select-all-users"
          @change="handleSelectAllUsers"
        />
      </template>
      <template #cell(checkbox)="{ item }">
        <gl-form-checkbox
          v-if="isBulkAddOnAssignmentEnabled"
          class="gl-min-h-5"
          :checked="isUserSelected(item)"
          @change="handleUserSelection(item, $event)"
        />
      </template>
      <template #cell(user)="{ item }">
        <slot name="user-cell" :item="item">
          <div class="gl-flex">
            <gl-avatar-link target="_blank" :href="item.webUrl" :alt="item.name">
              <gl-avatar-labeled
                :src="item.avatarUrl"
                :size="$options.avatarSize"
                :label="item.name"
                :sub-label="item.usernameWithHandle"
              />
            </gl-avatar-link>
          </div>
        </slot>
      </template>
      <template #cell(email)="{ item }">
        <div data-testid="email">
          <span v-if="item.publicEmail" class="gl-text-default">{{ item.publicEmail }}</span>
          <span
            v-else
            v-gl-tooltip
            :title="s__('Billing|An email address is only visible for users with public emails.')"
            class="gl-italic"
          >
            {{ s__('Billing|Private') }}
          </span>
        </div>
      </template>
      <template #cell(codeSuggestionsAddon)="{ item }">
        <code-suggestions-addon-assignment
          :user-id="item.id"
          :add-on-assignments="item.addOnAssignments"
          :add-on-purchase-id="addOnPurchaseId"
          :active-duo-tier="activeDuoTier"
          @handle-error="handleError"
          @clear-error="clearAlerts"
        />
      </template>
      <template #cell(maxRole)="{ item }">
        <gl-badge v-if="item.maxRole" data-testid="max-role">{{ item.maxRole }}</gl-badge>
      </template>
      <template #cell(lastActivityTime)="data">
        <span data-testid="last-activity-on">
          {{ data.item.lastActivityOn ? data.item.lastActivityOn : __('Never') }}
        </span>
      </template>
      <template #cell(lastDuoActivityTime)="{ item }">
        <span data-testid="last-duo-activity-on">
          {{ item.lastDuoActivityOn ? item.lastDuoActivityOn : __('Never') }}
        </span>
      </template>
    </gl-table>
    <div v-if="showPagination" class="gl-relative gl-mt-5 gl-justify-center gl-text-center">
      <gl-keyset-pagination v-bind="pageInfo" @prev="prevPage" @next="nextPage" />

      <page-size-selector
        :value="pageSize"
        class="gl-absolute gl-right-0 gl-top-0"
        @input="onPageSizeChange"
      />
    </div>

    <add-on-bulk-action-confirmation-modal
      v-if="isConfirmationModalVisible"
      :bulk-action="bulkAction"
      :user-count="selectedUsers.length"
      :is-bulk-action-in-progress="isBulkActionInProgress"
      @confirm-seat-assignment="assignSeats"
      @confirm-seat-unassignment="unassignSeats"
      @cancel="handleCancelBulkAction"
    />
  </section>
</template>
