<script>
import { GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import ApprovalsCountCe from '~/merge_requests/components/approval_count.vue';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

export default {
  name: 'ApprovalCount',
  components: {
    GlBadge,
    ApprovalsCountCe,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    mergeRequest: {
      type: Object,
      required: true,
    },
    fullText: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    approvedByCurrentUser() {
      const userID = convertToGraphQLId(TYPENAME_USER, gon.current_user_id || '');

      return this.mergeRequest.approvedBy?.nodes.some((u) => u.id === userID);
    },
    approvalText() {
      if (this.fullText) {
        if (this.mergeRequest.approved) {
          return __('Approved');
        }

        return sprintf(__('%{approvals_given} of %{required} Approvals'), {
          approvals_given: this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft,
          required: this.mergeRequest.approvalsRequired,
        });
      }

      return `${this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft}/${
        this.mergeRequest.approvalsRequired
      }`;
    },
    tooltipTitle() {
      return sprintf(
        this.approvedByCurrentUser
          ? __("Required approvals (%{approvals_given} of %{required} given, you've approved)")
          : __('Required approvals (%{approvals_given} of %{required} given)'),
        {
          approvals_given: this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft,
          required: this.mergeRequest.approvalsRequired,
        },
      );
    },
    badgeVariant() {
      return this.mergeRequest.approved ? 'success' : 'neutral';
    },
    badgeIcon() {
      if (this.mergeRequest.approved && this.approvedByCurrentUser) return 'approval-solid';
      if (this.mergeRequest.approved) return 'check-circle';

      return this.mergeRequest.approvalsRequired - this.mergeRequest.approvalsLeft > 0
        ? 'check-circle-dashed'
        : 'dash-circle';
    },
  },
};
</script>

<template>
  <button
    v-if="mergeRequest.approvalsRequired"
    v-gl-tooltip.viewport.top="tooltipTitle"
    :aria-label="tooltipTitle"
    class="!gl-cursor-default gl-rounded-pill gl-border-none gl-bg-transparent gl-p-0"
    data-testid="mr-approvals"
  >
    <gl-badge
      :icon="badgeIcon"
      :icon-optically-aligned="badgeIcon !== 'approval-solid'"
      :variant="badgeVariant"
    >
      {{ approvalText }}
    </gl-badge>
  </button>

  <approvals-count-ce v-else :merge-request="mergeRequest" :full-text="fullText" />
</template>
