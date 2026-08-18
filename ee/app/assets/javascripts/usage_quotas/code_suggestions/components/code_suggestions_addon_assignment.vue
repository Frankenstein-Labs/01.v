<script>
import { GlToggle } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__, sprintf } from '~/locale';
import { DUO_TITLES, DUO_IDENTIFIERS } from 'ee/constants/duo';
import {
  CANNOT_ASSIGN_ADDON_ERROR_CODE,
  CANNOT_UNASSIGN_ADDON_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import { isKnownErrorCode } from '~/lib/utils/error_utils';
import { InternalEvents } from '~/tracking';
import userAddOnAssignmentCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_create.mutation.graphql';
import userAddOnAssignmentRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_remove.mutation.graphql';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'CodeSuggestionsAddonAssignment',
  components: {
    GlToggle,
  },
  mixins: [trackingMixin],
  props: {
    userId: {
      type: String,
      required: true,
    },
    addOnAssignments: {
      type: Array,
      required: false,
      default: () => [],
    },
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    activeDuoTier: {
      type: String,
      required: true,
      validator: (value) => DUO_IDENTIFIERS.includes(value),
    },
  },
  emits: ['clear-error', 'handle-error'],
  data() {
    return {
      isLoading: false,
      toggleId: `toggle-${this.userId}`,
    };
  },
  computed: {
    isAssigned() {
      return Boolean(
        this.addOnAssignments?.find(
          (assignment) => assignment.addOnPurchase?.name === this.activeDuoTier,
        ),
      );
    },
    addOnAssignmentQueryVariables() {
      return {
        userId: this.userId,
        addOnPurchaseId: this.addOnPurchaseId,
      };
    },
    toggleLabel() {
      return sprintf(s__('CodeSuggestions|%{addOnName} status'), {
        addOnName: DUO_TITLES[this.activeDuoTier],
      });
    },
  },
  methods: {
    async onToggle() {
      this.isLoading = true;
      this.$emit('clear-error');

      try {
        const response = this.isAssigned ? await this.unassignAddOn() : await this.assignAddOn();
        const trackingAction = this.isAssigned
          ? 'disable_gitlab_duo_pro_for_seat'
          : 'enable_gitlab_duo_pro_for_seat';

        // Null response here means it didn't error but we're trying unassign an already unassigned user
        // https://gitlab.com/gitlab-org/gitlab/-/issues/426175 should take care of returning a response
        // instead of null value similar to how assignment mutation works when assigning an already assigned user
        if (!response) {
          return;
        }

        const errors = response.errors || [];
        if (errors.length) {
          this.handleError(errors[0]);
        }

        this.trackEvent(trackingAction);
      } catch (e) {
        this.handleError(e);
        Sentry.captureException(e);
      } finally {
        this.isLoading = false;
      }
    },
    handleError(e) {
      let error;

      if (isKnownErrorCode(e, ADD_ON_ERROR_DICTIONARY)) {
        error = e;
      } else if (this.isAssigned) {
        error = CANNOT_UNASSIGN_ADDON_ERROR_CODE;
      } else {
        error = CANNOT_ASSIGN_ADDON_ERROR_CODE;
      }

      this.$emit('handle-error', error);
    },
    async assignAddOn() {
      const {
        data: { userAddOnAssignmentCreate },
      } = await this.$apollo.mutate({
        mutation: userAddOnAssignmentCreateMutation,
        variables: this.addOnAssignmentQueryVariables,
      });
      return userAddOnAssignmentCreate;
    },
    async unassignAddOn() {
      const {
        data: { userAddOnAssignmentRemove },
      } = await this.$apollo.mutate({
        mutation: userAddOnAssignmentRemoveMutation,
        variables: this.addOnAssignmentQueryVariables,
      });
      return userAddOnAssignmentRemove;
    },
  },
};
</script>
<template>
  <div>
    <gl-toggle
      :id="toggleId"
      :value="isAssigned"
      :label="toggleLabel"
      :is-loading="isLoading"
      class="gl-inline-block gl-align-middle"
      label-position="hidden"
      @change="onToggle"
    />
  </div>
</template>
