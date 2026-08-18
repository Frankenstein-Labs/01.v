<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { isEqual, cloneDeep } from 'lodash-es';
import { __, s__ } from '~/locale';
import { EMPTY_CATALOGS, fetchCatalogs } from '../../catalog/catalogs';
import {
  STEP_BUILD,
  STEP_SCOPE,
  STEP_REVIEW,
  STEP_ORDER,
  STEP_LABELS,
  STATUS_COMPLETE,
  STATUS_CURRENT,
  STATUS_UPCOMING,
  SCOPE_ALL,
  ENFORCEMENT_ENFORCE,
} from './constants';
import { deserializePolicyData, deserializeScope, emptyPolicyData } from './serializer';
import BuildPolicyStep from './steps/build_policy_step.vue';
import ScopeStep from './steps/scope_step.vue';
import ReviewStep from './steps/review_step.vue';
import PolicyNameField from './policy_name_field.vue';
import WizardControls from './wizard_controls.vue';

export default {
  name: 'StepWizard',
  components: {
    GlButton,
    GlModal,
    BuildPolicyStep,
    ScopeStep,
    ReviewStep,
    PolicyNameField,
    WizardControls,
  },
  STEP_ORDER,
  cancelModalPrimary: {
    text: s__('PolicyStore|Discard changes'),
    attributes: { variant: 'danger' },
  },
  cancelModalCancel: {
    text: s__('PolicyStore|Continue editing'),
  },
  i18n: {
    cancel: __('Cancel'),
    back: __('Back'),
    next: __('Next'),
    save: s__('PolicyStore|Save policy'),
    stepPlaceholder: s__('PolicyStore|This step is coming soon.'),
    cancelTitle: s__('PolicyStore|Discard this policy?'),
    cancelBody: s__('PolicyStore|Your progress will be lost if you leave without saving.'),
  },
  props: {
    policy: {
      type: Object,
      required: false,
      default: null,
    },
    saving: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['cancel', 'save'],
  data() {
    const name = this.policy?.name || '';
    const description = this.policy?.description || '';
    const mode = this.policy?.mode || ENFORCEMENT_ENFORCE;
    const scope = this.policy
      ? deserializeScope(this.policy.policy_scope)
      : { mode: SCOPE_ALL, projects: [], exclusions: [] };
    const policyData = this.policy ? deserializePolicyData(this.policy) : emptyPolicyData();

    return {
      name,
      description,
      mode,
      scope,
      policyData,
      initialName: name,
      initialDescription: description,
      initialMode: mode,
      initialScope: cloneDeep(scope),
      initialPolicyData: cloneDeep(policyData),
      showCancelModal: false,
      currentStepIndex: 0,
      catalogs: EMPTY_CATALOGS,
      catalogsLoading: true,
      failedCatalogs: [],
    };
  },
  computed: {
    isDirty() {
      return (
        this.name !== this.initialName ||
        this.description !== this.initialDescription ||
        this.mode !== this.initialMode ||
        !isEqual(this.scope, this.initialScope) ||
        !isEqual(this.policyData, this.initialPolicyData)
      );
    },
    currentStepId() {
      return this.$options.STEP_ORDER[this.currentStepIndex];
    },
    isBuildStep() {
      return this.currentStepId === STEP_BUILD;
    },
    isScopeStep() {
      return this.currentStepId === STEP_SCOPE;
    },
    isReviewStep() {
      return this.currentStepId === STEP_REVIEW;
    },
    // Everything the review step summarises: the wizard-owned fields plus the Build
    // step's selections, flattened to id lists the catalogs can label.
    policyState() {
      const { trigger, rules, actions } = this.policyData;

      return {
        name: this.name,
        description: this.description,
        mode: this.mode,
        scope: this.scope,
        trigger,
        rules,
        actions,
      };
    },
    steps() {
      const { length } = this.$options.STEP_ORDER;
      return this.$options.STEP_ORDER.map((id, index) => ({
        id,
        number: index + 1,
        label: this.stepLabel(id),
        status: this.stepStatus(index),
        isLast: index === length - 1,
      }));
    },
    currentStepLabel() {
      return this.stepLabel(this.currentStepId);
    },
    isFirstStep() {
      return this.currentStepIndex === 0;
    },
    isLastStep() {
      return this.currentStepIndex === this.$options.STEP_ORDER.length - 1;
    },
    // The create endpoint requires a name, a trigger and at least one rule, so
    // the Save button waits for all three rather than submitting a known 400.
    canSave() {
      return Boolean(this.name.trim() && this.policyData.trigger && this.policyData.rules.length);
    },
  },
  created() {
    this.loadCatalogs();
  },
  methods: {
    async loadCatalogs() {
      this.catalogsLoading = true;
      this.failedCatalogs = [];

      try {
        const { catalogs, failedCatalogs } = await fetchCatalogs();

        this.catalogs = catalogs;
        this.failedCatalogs = failedCatalogs;
      } catch {
        this.failedCatalogs = ['triggers', 'rules', 'actions'];
      } finally {
        this.catalogsLoading = false;
      }
    },
    stepLabel(id) {
      return STEP_LABELS[id];
    },
    stepStatus(index) {
      if (index < this.currentStepIndex) return STATUS_COMPLETE;
      if (index === this.currentStepIndex) return STATUS_CURRENT;
      return STATUS_UPCOMING;
    },
    closeCancelModal() {
      this.showCancelModal = false;
    },
    requestCancel() {
      if (this.isDirty) {
        this.showCancelModal = true;
      } else {
        this.$emit('cancel');
      }
    },
    onModeSelect(mode) {
      this.mode = mode;
    },
    onScopeUpdate(scope) {
      this.scope = scope;
    },
    onEditPolicy() {
      this.currentStepIndex = 0;
    },
    back() {
      if (!this.isFirstStep) this.currentStepIndex -= 1;
    },
    next() {
      if (!this.isLastStep) this.currentStepIndex += 1;
    },
    requestSave() {
      this.$emit('save', {
        name: this.name,
        description: this.description,
        mode: this.mode,
        scope: this.scope,
        // The wizard only understands project scoping, so the save handler
        // needs to know whether the scope was touched before overwriting a
        // scope authored through the API (Rego, groups, frameworks).
        scopeChanged: !isEqual(this.scope, this.initialScope),
        policyData: this.policyData,
      });
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5 gl-pt-6">
    <div class="gl-flex gl-flex-col gl-gap-4 md:gl-flex-row md:gl-items-center">
      <policy-name-field
        class="gl-w-full gl-flex-shrink-0 md:gl-w-1/4"
        :name="name"
        :description="description"
        @update:name="name = $event"
        @update:description="description = $event"
      />
      <div class="gl-min-w-0 gl-flex-1">
        <wizard-controls :steps="steps" :mode="mode" @select-mode="onModeSelect" />
      </div>
    </div>

    <build-policy-step
      v-if="isBuildStep"
      :policy-data="policyData"
      :catalogs="catalogs"
      :catalogs-loading="catalogsLoading"
      :failed-catalogs="failedCatalogs"
      data-testid="wizard-step-content"
      @update="policyData = $event"
    />
    <scope-step
      v-else-if="isScopeStep"
      :scope="scope"
      class="gl-my-6"
      data-testid="wizard-step-content"
      @update="onScopeUpdate"
    />
    <review-step
      v-else-if="isReviewStep"
      :policy="policyState"
      :catalogs="catalogs"
      class="gl-my-6"
      data-testid="wizard-step-content"
      @edit="onEditPolicy"
    />
    <div
      v-else
      data-testid="wizard-step-content"
      class="gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-p-6 gl-text-subtle"
    >
      <h3 class="gl-heading-3 gl-mb-2">{{ currentStepLabel }}</h3>
      <p class="gl-mb-0">{{ $options.i18n.stepPlaceholder }}</p>
    </div>

    <div
      class="gl-z-10 gl-border-t gl-sticky gl-bottom-0 gl-flex gl-flex-shrink-0 gl-items-center gl-justify-between gl-border-subtle gl-bg-default gl-px-6 gl-py-3"
    >
      <gl-button @click="requestCancel">
        {{ $options.i18n.cancel }}
      </gl-button>
      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-button v-if="!isFirstStep" @click="back">{{ $options.i18n.back }}</gl-button>
        <gl-button v-if="!isLastStep" variant="confirm" :disabled="catalogsLoading" @click="next">
          {{ $options.i18n.next }}
        </gl-button>
        <gl-button
          v-if="isLastStep"
          variant="confirm"
          :disabled="!canSave"
          :loading="saving"
          data-testid="save-policy-button"
          @click="requestSave"
        >
          {{ $options.i18n.save }}
        </gl-button>
      </div>
    </div>

    <gl-modal
      modal-id="policy-store-cancel-modal"
      :visible="showCancelModal"
      :title="$options.i18n.cancelTitle"
      :action-primary="$options.cancelModalPrimary"
      :action-cancel="$options.cancelModalCancel"
      @primary="$emit('cancel')"
      @hidden="closeCancelModal"
    >
      {{ $options.i18n.cancelBody }}
    </gl-modal>
  </div>
</template>
