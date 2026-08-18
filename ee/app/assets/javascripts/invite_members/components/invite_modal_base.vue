<script>
import { GlLink } from '@gitlab/ui';
import { partition, isString } from 'lodash-es';
import { ACCESS_LEVEL_LABELS } from '~/access_level/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import CeInviteModalBase from '~/invite_members/components/invite_modal_base.vue';
import getProjectMemberRoles from 'ee/graphql_shared/queries/project_member_roles.query.graphql';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import apolloProvider from '../provider';
import {
  OVERAGE_MODAL_LINK,
  OVERAGE_MODAL_TITLE,
  OVERAGE_MODAL_BACK_BUTTON,
  OVERAGE_MODAL_CONTINUE_BUTTON,
  OVERAGE_MODAL_LINK_TEXT,
  overageModalInfoText,
  overageModalInfoWarning,
} from '../constants';
import getReconciliationStatus from '../graphql/queries/subscription_eligible.customer.query.graphql';
import getBillableUserCountChanges from '../graphql/queries/billable_users_count.query.graphql';
import getGroupMemberRoles from '../graphql/queries/group_member_roles.query.graphql';

const OVERAGE_CONTENT_SLOT = 'overage-content';
const EXTRA_SLOTS = [
  {
    key: OVERAGE_CONTENT_SLOT,
    attributes: {
      class: 'invite-modal-content',
      'data-testid': 'invite-modal-overage-content',
    },
  },
];

export default {
  name: 'EEInviteModalBase',
  components: {
    GlLink,
    CeInviteModalBase,
  },
  mixins: [glSlotsMixin, glListenersMixin],
  apolloProvider,
  inject: {
    overageMembersModalAvailable: {
      default: false,
    },
    inviteWithCustomRoleEnabled: {
      default: false,
    },
    rootGroupPath: {}, // required
  },
  inheritAttrs: false,
  props: {
    accessLevels: {
      type: Object,
      required: true,
    },
    name: {
      type: String,
      required: true,
    },
    modalTitle: {
      type: String,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
    rootGroupId: {
      type: String,
      required: false,
      default: '',
    },
    newUsersToInvite: {
      type: Array,
      required: false,
      default: () => [],
    },
    newGroupToInvite: {
      type: Number,
      required: false,
      default: null,
    },
    submitDisabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    reachedLimit: {
      type: Boolean,
      required: false,
      default: false,
    },
    invalidFeedbackMessage: {
      type: String,
      required: false,
      default: '',
    },
    isGroupInvite: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    isProject: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasErrorDuringInvite: {
      type: Boolean,
      required: false,
      default: false,
    },
    hasIncompleteMemberInput: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['reset', 'submit'],
  apollo: {
    memberRoles: {
      client: 'gitlabClient',
      query() {
        return this.isProject ? getProjectMemberRoles : getGroupMemberRoles;
      },
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        const memberRoles = data?.namespace?.memberRoles?.nodes || [];
        return memberRoles.map(({ id, name, description, baseAccessLevel }) => ({
          baseAccessLevel: baseAccessLevel.integerValue,
          name,
          description,
          memberRoleId: getIdFromGraphQLId(id),
        }));
      },
      error(error) {
        Sentry.captureException(error);
      },
      skip() {
        if (this.isGroupInvite) {
          return !this.inviteWithCustomRoleEnabled || !this.isVisible;
        }

        return !this.isVisible;
      },
    },
  },
  data() {
    return {
      willIncreaseOverage: false,
      rootGroupName: '',
      totalUserCount: null,
      subscriptionSeats: 0,
      namespaceId: parseInt(this.rootGroupId, 10),
      currentlyLoading: false,
      isVisible: false,
      actualFeedbackMessage: this.invalidFeedbackMessage,
      memberRoles: [],
    };
  },
  computed: {
    isLoadingRoles() {
      return this.$apollo.queries.memberRoles.loading;
    },
    currentSlot() {
      if (this.showOverageModal) {
        return OVERAGE_CONTENT_SLOT;
      }

      // Use CE default
      return undefined;
    },
    showOverageModal() {
      if (this.hasErrorDuringInvite) {
        return false;
      }

      return (
        this.willIncreaseOverage && this.overageMembersModalAvailable && !this.actualFeedbackMessage
      );
    },
    submitDisabledEE() {
      if (this.showOverageModal) {
        return false;
      }

      // Use CE default
      return this.submitDisabled;
    },
    modalInfo() {
      if (this.totalUserCount) {
        const infoText = overageModalInfoText(this.subscriptionSeats);
        const infoWarning = overageModalInfoWarning(this.totalUserCount, this.rootGroupName);

        return `${infoText} ${infoWarning}`;
      }
      return '';
    },
    modalTitleOverride() {
      return this.showOverageModal ? OVERAGE_MODAL_TITLE : this.modalTitle;
    },
    overageModalButtons() {
      if (this.showOverageModal) {
        return {
          submit: OVERAGE_MODAL_CONTINUE_BUTTON,
          cancel: OVERAGE_MODAL_BACK_BUTTON,
        };
      }

      // Use CE default
      return {};
    },
    hasInput() {
      return (
        Boolean(this.newGroupToInvite || this.newUsersToInvite.length !== 0) &&
        !this.hasIncompleteMemberInput
      );
    },
    upgradedRoles() {
      return {
        ...this.accessLevels,
        customRoles: this.memberRoles,
      };
    },
    computedIsLoading() {
      return this.isLoading || this.currentlyLoading;
    },
  },
  watch: {
    invalidFeedbackMessage(newValue) {
      this.willIncreaseOverage = false;
      this.actualFeedbackMessage = newValue;
    },
  },
  methods: {
    getPassthroughListeners() {
      // This gets the listeners we don't manually handle here
      // so we can pass them through to the CE invite_modal_base.vue
      const { reset, submit, ...listeners } = this.glListeners();

      return listeners;
    },
    onReset() {
      // don't reopen the overage modal
      this.willIncreaseOverage = false;
      this.actualFeedbackMessage = '';
      this.isVisible = false;

      this.$emit('reset');
    },
    onSubmit(args) {
      if (this.reachedLimit) return;

      if (this.overageMembersModalAvailable && !this.willIncreaseOverage && this.hasInput) {
        this.actualFeedbackMessage = '';
        this.checkEligibility(args);
      } else {
        this.emitSubmit(args);
      }
    },
    checkEligibility(args) {
      this.currentlyLoading = true;
      this.$apollo.addSmartQuery('eligibleForSeatReconciliation', {
        client: 'customersDotClient',
        query: getReconciliationStatus,
        variables() {
          return {
            namespaceId: this.namespaceId,
          };
        },
        update(data) {
          return data.reconciliation?.eligibleForSeatReconciliation;
        },
        result({ data }) {
          if (data?.reconciliation?.eligibleForSeatReconciliation) {
            this.checkAndSubmit(args);
            return;
          }
          // we don't want to block the flow if API response has unexpected data
          this.emitSubmit(args);
          this.currentlyLoading = false;
        },
        error(er) {
          this.currentlyLoading = false;
          Sentry.captureException(er);
        },
      });
    },
    async checkAndSubmit(args) {
      const variables = this.overageVariables(args);

      try {
        this.currentlyLoading = true;
        const { data } = await this.$apollo.query({
          query: getBillableUserCountChanges,
          client: 'gitlabClient',
          variables,
          fetchPolicy: 'no-cache',
        });

        if (!data?.group?.gitlabSubscriptionsPreviewBillableUserChange) {
          // we don't want to block the flow if API response has unexpected data
          this.emitSubmit(args);

          return;
        }
        const billingDetails = data.group.gitlabSubscriptionsPreviewBillableUserChange;
        this.willIncreaseOverage = billingDetails.willIncreaseOverage;
        if (this.willIncreaseOverage) {
          this.rootGroupName = data.group.name;
          this.totalUserCount = billingDetails.newBillableUserCount;
          this.subscriptionSeats = billingDetails.seatsInSubscription;
        } else {
          this.emitSubmit(args);
        }
      } catch (error) {
        // do smth with error
        this.emitSubmit(args);
        Sentry.captureException(error);
      } finally {
        this.currentlyLoading = false;
      }
    },
    emitSubmit({ accessLevel, expiresAt, memberRoleId } = {}) {
      this.$emit('submit', { accessLevel, expiresAt, memberRoleId });
    },
    partitionNewUsersToInvite() {
      const [usersToInviteByEmail, usersToAddById] = partition(
        this.newUsersToInvite,
        ({ id }) => isString(id) && id.includes('user-defined-token'),
      );

      return [usersToInviteByEmail.map(({ name }) => name), usersToAddById.map(({ id }) => id)];
    },
    overageVariables({ accessLevel, memberRoleId }) {
      const [usersToInviteByEmail, usersToAddById] = this.partitionNewUsersToInvite();
      const addGroupId = this.newGroupToInvite;

      return {
        fullPath: this.rootGroupPath,
        addGroupId,
        addUserEmails: usersToInviteByEmail,
        addUserIds: usersToAddById,
        role: ACCESS_LEVEL_LABELS[accessLevel].toUpperCase(),
        memberRoleId,
      };
    },
    onCancel() {
      if (this.showOverageModal) {
        this.willIncreaseOverage = false;
      }
    },
  },
  i18n: {
    OVERAGE_MODAL_TITLE,
    OVERAGE_MODAL_LINK,
    OVERAGE_MODAL_BACK_BUTTON,
    OVERAGE_MODAL_CONTINUE_BUTTON,
    OVERAGE_MODAL_LINK_TEXT,
  },
  OVERAGE_CONTENT_SLOT,
  EXTRA_SLOTS,
};
</script>

<template>
  <ce-invite-modal-base
    v-bind="$attrs"
    :name="name"
    :access-levels="upgradedRoles"
    :submit-button-text="overageModalButtons.submit"
    :cancel-button-text="overageModalButtons.cancel"
    :modal-title="modalTitleOverride"
    :current-slot="currentSlot"
    :extra-slots="$options.EXTRA_SLOTS"
    :submit-disabled="submitDisabledEE"
    :prevent-cancel-default="showOverageModal"
    :reached-limit="reachedLimit"
    :is-loading="computedIsLoading"
    :is-loading-roles="isLoadingRoles"
    :invalid-feedback-message="actualFeedbackMessage"
    @reset="onReset"
    @submit="onSubmit"
    @cancel="onCancel"
    @shown="isVisible = true"
    v-on="getPassthroughListeners()"
  >
    <template #[$options.OVERAGE_CONTENT_SLOT]>
      {{ modalInfo }}
      <gl-link :href="$options.i18n.OVERAGE_MODAL_LINK" target="_blank"
        >{{ $options.i18n.OVERAGE_MODAL_LINK_TEXT }}
      </gl-link>
    </template>
    <template v-for="(_, slot) of glSlots()" #[slot]="scope">
      <slot :name="slot" v-bind="scope"></slot>
    </template>
  </ce-invite-modal-base>
</template>
