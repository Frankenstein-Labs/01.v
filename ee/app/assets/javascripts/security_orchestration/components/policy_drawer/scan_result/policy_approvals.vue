<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { s__, n__, __, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_MEMBER_ROLE, TYPENAME_USER } from '~/graphql_shared/constants';

const THRESHOLD_FOR_APPROVERS = 3;

export default {
  name: 'PolicyApprovals',
  i18n: {
    actionText: s__('SecurityOrchestration|Require %{approvals} %{plural} from %{approvers}'),
    noActionText: s__('SecurityOrchestration|Requires no approvals if any of the following occur:'),
    additional_approvers: s__('SecurityOrchestration|, and %{count} more'),
    and: __(' and '),
    comma: __(', '),
    warnModeText: s__(
      'SecurityOrchestration|Warn users with a bot comment and require users to either dismiss the policy or obtain %{approvals} %{plural} from %{approvers}',
    ),
  },
  components: {
    GlSprintf,
    GlLink,
  },
  props: {
    action: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    approvers: {
      type: Array,
      required: true,
    },
    isLastItem: {
      type: Boolean,
      required: false,
      default: false,
    },
    isWarnMode: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    approvalsRequired() {
      return this.action.approvals_required;
    },
    approvalsText() {
      return n__('approval', 'approvals', this.approvalsRequired);
    },
    displayedApprovers() {
      return this.approvers.slice(0, THRESHOLD_FOR_APPROVERS);
    },
    isEmptyAction() {
      return isEmpty(this.action);
    },
    showSeparator() {
      return !this.isLastItem && !this.isEmptyAction && !this.isWarnMode;
    },
    message() {
      if (this.isWarnMode) {
        return this.$options.i18n.warnModeText;
      }

      return this.isEmptyAction ? this.$options.i18n.noActionText : this.$options.i18n.actionText;
    },
  },
  methods: {
    isCustomRoleType(approver) {
      return approver?.id?.includes(TYPENAME_MEMBER_ROLE);
    },
    isRoleType(approver) {
      return typeof approver === 'string';
    },
    isUserType(approver) {
      return approver?.id?.includes(TYPENAME_USER);
    },
    displayName(approver) {
      return this.isUserType(approver) ? approver.name : approver.fullPath;
    },
    additionalText(approver) {
      const index = this.displayedApprovers.findIndex((current) => current === approver);
      const remainingApprovers = this.approvers.length - THRESHOLD_FOR_APPROVERS;
      const displayAdditionalApprovers = remainingApprovers > 0;

      if (index === -1) {
        return '';
      }

      if (displayAdditionalApprovers) {
        if (index === this.displayedApprovers.length - 1) {
          return sprintf(this.$options.i18n.additional_approvers, {
            count: remainingApprovers,
          });
        }
        if (index < this.displayedApprovers.length - 1) {
          return this.$options.i18n.comma;
        }
      } else if (index === this.displayedApprovers.length - 2) {
        return this.$options.i18n.and;
      } else if (index < this.displayedApprovers.length - 2) {
        return this.$options.i18n.comma;
      }
      return '';
    },
    attributeValue(approver) {
      // The data-user attribute is required for the user popover
      // Since the popover is only for users, this method returns false if not a user to hide the
      // data-user attribute
      return this.isUserType(approver) ? getIdFromGraphQLId(approver.id) : false;
    },
  },
};
</script>

<template>
  <span>
    <gl-sprintf :message="message">
      <template #approvals>
        {{ approvalsRequired }}
      </template>
      <template #plural>
        {{ approvalsText }}
      </template>
      <template #approvers>
        <span v-for="approver in displayedApprovers" :key="approver.id || approver">
          <span v-if="isRoleType(approver)" :data-testid="approver">{{ approver }}</span>
          <span v-else-if="isCustomRoleType(approver)" :data-testid="approver.name">{{
            approver.name
          }}</span>
          <gl-link
            v-else
            :href="approver.webUrl"
            :data-user="attributeValue(approver)"
            :data-testid="approver.id"
            target="_blank"
            class="gfm gfm-project_member js-user-link"
          >
            {{ displayName(approver) }}</gl-link
          >{{ additionalText(approver) }}
        </span>
      </template>
    </gl-sprintf>

    <span v-if="showSeparator" class="action-separator gl-my-1 gl-block gl-text-subtle">{{
      $options.i18n.and
    }}</span>
  </span>
</template>
