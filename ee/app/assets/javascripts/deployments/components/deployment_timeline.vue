<script>
import { GlAvatarLink, GlAvatar, GlBadge, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import TimelineEntryItem from '~/vue_shared/components/notes/timeline_entry_item.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { APPROVAL_STATUSES, ACCESS_LEVEL } from '../constants';

export default {
  name: 'DeploymentTimeline',
  components: {
    GlAvatarLink,
    GlAvatar,
    GlBadge,
    GlLink,
    TimelineEntryItem,
    TimeAgoTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    approvalSummary: {
      type: Object,
      required: true,
    },
  },
  computed: {
    approvals() {
      return this.approvalSummary.rules
        .flatMap((rule) => rule.approvals)
        .sort((a, b) => (a.createdAt <= b.createdAt ? -1 : 1));
    },
    hasApprovals() {
      return this.approvals.length > 0;
    },
  },
  methods: {
    getUserId({ user }) {
      return getIdFromGraphQLId(user.id);
    },
    badgeVariant({ status }) {
      return status === APPROVAL_STATUSES.APPROVED ? 'success' : 'danger';
    },
    badgeText({ status }) {
      return status === APPROVAL_STATUSES.APPROVED
        ? this.$options.i18n.approved
        : this.$options.i18n.rejected;
    },
    badgeTooltip(approval) {
      const relatedRule = this.approvalSummary.rules.find((rule) =>
        rule?.approvals.find(
          (ruleApproval) => ruleApproval.user.username === approval.user.username,
        ),
      );

      if (!relatedRule) {
        return '';
      }

      const role =
        relatedRule.user?.name ||
        relatedRule.group?.name ||
        ACCESS_LEVEL[relatedRule.accessLevel?.stringValue]?.display;

      return approval.status === APPROVAL_STATUSES.APPROVED
        ? sprintf(this.$options.i18n.approvedAs, { role })
        : sprintf(this.$options.i18n.rejectedAs, { role });
    },
  },
  i18n: {
    header: s__('Deployment|Approval Activity'),
    approved: s__('Deployment|Approved'),
    rejected: s__('Deployment|Rejected'),
    approvedAs: s__('Deployment|Approved as %{role}'),
    rejectedAs: s__('Deployment|Rejected as %{role}'),
  },
};
</script>
<template>
  <div v-if="hasApprovals" class="issuable-discussion">
    <h3>{{ $options.i18n.header }}</h3>

    <ul class="notes main-notes-list timeline">
      <timeline-entry-item
        v-for="(approval, i) in approvals"
        :key="i"
        :data-testid="`approval-${approval.user.username}`"
        class="note note-wrapper note-comment"
      >
        <div class="timeline-avatar gl-float-left">
          <gl-avatar-link :href="approval.user.webUrl">
            <gl-avatar
              :src="approval.user.avatarUrl"
              :entity-name="approval.user.username"
              :alt="approval.user.name"
              :size="32"
            />
          </gl-avatar-link>
        </div>
        <div class="timeline-content">
          <div class="note-header">
            <div class="note-header-info">
              <gl-link
                :href="approval.user.webUrl"
                :data-username="approval.user.username"
                :data-user-id="getUserId(approval)"
                class="js-user-link"
              >
                {{ approval.user.name }}
                <span class="note-headline-light">@{{ approval.user.username }}</span>
              </gl-link>
              <span class="note-headline-light"> &middot; </span>
              <gl-badge
                v-gl-tooltip
                :variant="badgeVariant(approval)"
                :title="badgeTooltip(approval)"
              >
                {{ badgeText(approval) }}
              </gl-badge>
              <span class="note-headline-light"> &middot; </span>
              <span class="note-headline-light">
                <time-ago-tooltip :time="approval.createdAt" />
              </span>
            </div>
          </div>
          <div
            v-if="approval.comment"
            :data-testid="`approval-comment-${approval.user.username}`"
            class="timeline-discussion-body"
          >
            <div class="note-body">{{ approval.comment }}</div>
          </div>
        </div>
      </timeline-entry-item>
    </ul>
  </div>
</template>
