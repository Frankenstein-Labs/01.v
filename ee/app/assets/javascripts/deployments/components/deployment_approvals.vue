<script>
import {
  GlAlert,
  GlButton,
  GlFormGroup,
  GlFormTextarea,
  GlIcon,
  GlTooltipDirective as GlTooltip,
} from '@gitlab/ui';
import { __, n__, s__ } from '~/locale';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { isFinished } from '~/deployments/utils';
import MultipleApprovalRulesTable from 'ee/environments/components/multiple_approval_rules_table.vue';
import approveDeploymentMutation from '../graphql/mutations/approve_deployment.mutation.graphql';

const MAX_CHARACTER_COUNT = 250;
const WARNING_CHARACTERS_LEFT = 30;
const APPROVE_STATUS = 'APPROVED';
const REJECT_STATUS = 'REJECTED';

export default {
  name: 'DeploymentApprovals',
  components: {
    MultipleApprovalRulesTable,
    GlAlert,
    GlButton,
    GlFormGroup,
    GlFormTextarea,
    GlIcon,
  },
  directives: {
    GlTooltip,
  },
  props: {
    approvalSummary: { required: true, type: Object },
    deployment: { required: true, type: Object },
  },
  emits: ['change'],
  data() {
    return {
      comment: '',
      errorMessage: '',
      approveLoading: false,
      rejectLoading: false,
      selectedRule: null,
    };
  },
  computed: {
    header() {
      return n__(
        'Deployment|Requires %d approval',
        'Deployment|Requires %d approvals',
        this.approvalSummary?.totalPendingApprovalCount,
      );
    },
    requiresApproval() {
      return this.approvalSummary.totalRequiredApprovals > 0;
    },
    remainingCharacterCount() {
      return MAX_CHARACTER_COUNT - this.comment.length;
    },
    hasApprovedDeployment() {
      return this.approvalSummary.rules
        .flatMap((rule) => {
          return rule.approvals;
        })
        .some((approval) => {
          return getIdFromGraphQLId(approval.user.id) === gon.current_user_id;
        });
    },
    commentCharacterCountClasses() {
      return {
        'gl-text-warning':
          this.remainingCharacterCount <= WARNING_CHARACTERS_LEFT &&
          this.remainingCharacterCount >= 0,
        'gl-text-danger': this.remainingCharacterCount < 0,
      };
    },
    characterCountTooltip() {
      return this.isCommentValid
        ? this.$options.i18n.charactersLeft
        : this.$options.i18n.charactersOverLimit;
    },
    hasError() {
      return Boolean(this.errorMessage);
    },
    approvalValid() {
      return this.remainingCharacterCount > 0;
    },
    isCommentValid() {
      return this.comment.length <= MAX_CHARACTER_COUNT;
    },
    canApproveDeployment() {
      return this.deployment.userPermissions.approveDeployment;
    },
    classes() {
      return {
        '@lg/panel:gl-border-b': this.needsApproval,
      };
    },
    needsApproval() {
      return (
        this.canApproveDeployment &&
        this.approvalSummary.status === 'PENDING_APPROVAL' &&
        !this.hasApprovedDeployment &&
        !this.isFinished(this.deployment)
      );
    },
    disableSubmit() {
      return !this.approvalValid || this.approveLoading || this.rejectLoading;
    },
  },
  methods: {
    isFinished,
    approve() {
      this.approveLoading = true;
      return this.actOnDeployment(APPROVE_STATUS).finally(() => {
        this.approveLoading = false;
      });
    },
    reject() {
      this.rejectLoading = true;
      return this.actOnDeployment(REJECT_STATUS).finally(() => {
        this.rejectLoading = false;
      });
    },
    actOnDeployment(status) {
      return this.$apollo
        .mutate({
          mutation: approveDeploymentMutation,
          variables: {
            input: {
              id: this.deployment.id,
              comment: this.comment,
              representedAs: this.selectedRule,
              status,
            },
          },
        })
        .then(({ data }) => {
          const { errors = [] } = data.approveDeployment;
          if (errors.length) {
            [this.errorMessage] = errors;
          }
          this.$emit('change');
          this.comment = '';
        })
        .catch((err) => {
          this.errorMessage = this.$options.i18n.genericError;
          captureException(err);
        });
    },
    onRuleSelected($event) {
      this.selectedRule = $event;
    },
  },
  i18n: {
    approvalCommentLabel: s__('Deployment|Add approval comment'),
    charactersLeft: __('Characters left'),
    charactersOverLimit: __('Characters over limit'),
    optionalText: __('(optional)'),
    genericError: s__(
      'Deployment|Something went wrong approving or rejecting the deployment. Please try again later.',
    ),
    approve: s__('Deployment|Approve deployment'),
    reject: s__('Deployment|Reject'),
  },
};
</script>
<template>
  <div
    v-if="requiresApproval"
    class="@lg/panel:gl-border-t @lg/panel:gl-border-r @lg/panel:gl-border-l @lg/panel:gl-rounded-base"
    :class="classes"
  >
    <div class="gl-m-5 gl-block gl-font-bold" data-testid="deployment-approval-header">
      <gl-icon name="approval" class="gl-mr-2" /> <span>{{ header }}</span>
    </div>
    <multiple-approval-rules-table :rules="approvalSummary.rules" @select-rule="onRuleSelected" />

    <template v-if="needsApproval">
      <div class="gl-m-5 gl-flex gl-flex-col">
        <gl-alert v-if="hasError" variant="danger" class="gl-mb-5" @dismiss="errorMessage = ''">
          {{ errorMessage }}
        </gl-alert>
        <gl-form-group
          :label="$options.i18n.approvalCommentLabel"
          label-for="deployment-approval-comment"
          :optional-text="$options.i18n.optionalText"
          optional
          class="gl-mb-2"
        >
          <gl-form-textarea
            id="deployment-approval-comment"
            v-model="comment"
            :state="approvalValid"
            no-resize
          />
        </gl-form-group>
        <span
          v-gl-tooltip
          :title="characterCountTooltip"
          :class="commentCharacterCountClasses"
          data-testid="approval-character-count"
          class="gl-self-end"
        >
          {{ remainingCharacterCount }}
        </span>
      </div>
      <div class="gl-m-5 gl-flex gl-justify-end gl-gap-3">
        <gl-button
          :loading="approveLoading"
          :disabled="disableSubmit"
          variant="confirm"
          @click="approve"
        >
          {{ $options.i18n.approve }}
        </gl-button>
        <gl-button :loading="rejectLoading" :disabled="disableSubmit" @click="reject">
          {{ $options.i18n.reject }}
        </gl-button>
      </div>
    </template>
  </div>
</template>
