<script>
import { GlAlert, GlModal, GlFormGroup, GlFormTextarea, GlCollapsibleListbox } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  POLICY_EXCEPTIONS_NEXT_STEPS,
  POLICY_EXCEPTIONS_BYPASS_REASONS,
} from 'ee/vue_merge_request_widget/components/checks/constants';
import bypassSecurityPolicyExceptionViolations from './queries/bypass_security_policy_exception_violation.mutation.graphql';

export default {
  POLICY_EXCEPTIONS_BYPASS_REASONS,
  POLICY_EXCEPTIONS_NEXT_STEPS,
  ACTION_CANCEL: { text: __('Cancel') },
  name: 'SecurityPolicyBypassStatusesModal',
  components: {
    GlAlert,
    GlModal,
    GlFormGroup,
    GlFormTextarea,
    GlCollapsibleListbox,
  },
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    mr: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    policies: {
      type: Array,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close', 'saved'],
  data() {
    return {
      bypassReasonTextAreaDirty: false,
      bypassReason: '',
      loading: false,
      selectedPolicies: [],
      selectedReason: '',
      showErrorAlert: false,
    };
  },
  computed: {
    actionPrimary() {
      return {
        text: __('Bypass'),
        attributes: {
          variant: 'danger',
          disabled: !this.isValid,
          loading: this.loading,
          'data-testid': 'bypass-policy-violations-button',
        },
      };
    },
    isBypassReasonEmpty() {
      return this.bypassReason.trim().length === 0;
    },
    isValid() {
      return (
        this.selectedPolicies.length > 0 && this.selectedReason !== '' && !this.isBypassReasonEmpty
      );
    },
    selectedReasonText() {
      return (
        POLICY_EXCEPTIONS_BYPASS_REASONS.find(({ value }) => value === this.selectedReason)?.text ||
        s__('SecurityOrchestration|Select bypass reasons')
      );
    },
    bypassReasonState() {
      return !(this.bypassReasonTextAreaDirty && this.isBypassReasonEmpty);
    },
    policyItems() {
      return this.policies.map((policy) => ({
        ...policy,
        text: policy.name,
        value: policy.id,
      }));
    },
    selectedPolicyText() {
      return getSelectedOptionsText({
        options: this.policyItems,
        selected: this.selectedPolicies,
        placeholder: s__('SecurityOrchestration|Select policies'),
        maxOptionsShown: 2,
      });
    },
  },
  methods: {
    async handleBypass() {
      this.loading = true;

      try {
        const {
          data: {
            mergeRequestBypassSecurityPolicy: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: bypassSecurityPolicyExceptionViolations,
          variables: {
            iid: this.mr.iid.toString(),
            projectPath: this.mr.targetProjectFullPath,
            securityPolicyIds: this.selectedPolicies?.map((id) => getIdFromGraphQLId(id)),
            reason: `${this.selectedReason}:${this.bypassReason}`,
          },
        });

        if (errors?.length) {
          throw Error(errors.join(','));
        }

        this.handleClose();
        this.$emit('saved');
      } catch (e) {
        this.showErrorAlert = true;
        Sentry.captureException(e);
      } finally {
        this.loading = false;
      }
    },
    handleClose() {
      this.$emit('close');
    },
    handleChange(opened) {
      if (!opened) {
        this.handleClose();
      }
    },
    handleSelect(property, value) {
      this[property] = value;
    },
    updateBypassReason(value) {
      this.bypassReasonTextAreaDirty = true;
      this.bypassReason = value;
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    modal-id="security-policy-violations-modal"
    :title="s__('SecurityOrchestration|Bypass Policy Violation')"
    :action-primary="actionPrimary"
    :action-cancel="$options.ACTION_CANCEL"
    size="md"
    @primary.prevent="handleBypass"
    @cancel="handleClose"
    @change="handleChange"
  >
    <gl-alert variant="info" :dismissible="false" class="gl-mb-4" :title="__('What happens next?')">
      <ul class="gl-mb-0 gl-pl-5">
        <li v-for="step in $options.POLICY_EXCEPTIONS_NEXT_STEPS" :key="step">
          {{ step }}
        </li>
      </ul>
    </gl-alert>

    <gl-alert
      v-if="showErrorAlert"
      data-testid="error-message"
      class="gl-mb-5"
      variant="danger"
      :dismissible="false"
      :title="s__('SecurityOrchestration|Policy bypass failed')"
    >
      {{
        s__(
          'SecurityOrchestration|An error occurred while attempting to bypass policies. Please refresh the page and try again.',
        )
      }}
    </gl-alert>

    <div data-testid="modal-content">
      <gl-form-group
        :label="s__('SecurityOrchestration|Select policies to bypass')"
        label-for="policy-selector"
        class="gl-mb-4"
      >
        <gl-collapsible-listbox
          data-testid="policy-selector"
          block
          multiple
          :items="policyItems"
          :selected="selectedPolicies"
          :toggle-text="selectedPolicyText"
          @select="handleSelect('selectedPolicies', $event)"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('SecurityOrchestration|Bypassed as')"
        label-for="reason-selector"
        class="gl-mb-4"
      >
        <gl-collapsible-listbox
          :selected="selectedReason"
          block
          :multiple="false"
          :items="$options.POLICY_EXCEPTIONS_BYPASS_REASONS"
          :toggle-text="selectedReasonText"
          data-testid="reason-selector"
          @select="handleSelect('selectedReason', $event)"
        />
      </gl-form-group>

      <gl-form-group
        :label="s__('SecurityOrchestration|Reason for policy bypass')"
        label-for="bypass-reason-textarea"
        class="gl-mb-0"
      >
        <gl-form-textarea
          rows="4"
          :debounce="$options.DEFAULT_DEBOUNCE_AND_THROTTLE_MS"
          :placeholder="
            s__('SecurityOrchestration|Provide a detailed justification for policy bypass.')
          "
          :state="bypassReasonState"
          :value="bypassReason"
          @input="updateBypassReason"
        />
      </gl-form-group>
      <p class="gl-text-gray-300">
        {{ s__('SecurityOrchestration|Comments are required when bypassing policies.') }}
      </p>
    </div>
  </gl-modal>
</template>
