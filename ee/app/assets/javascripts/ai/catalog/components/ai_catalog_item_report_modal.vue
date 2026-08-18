<script>
import { uniqueId } from 'lodash-es';
import {
  GlForm,
  GlFormCharacterCount,
  GlFormGroup,
  GlFormRadio,
  GlFormRadioGroup,
  GlFormTextarea,
  GlModal,
} from '@gitlab/ui';
import { __, s__, n__, sprintf } from '~/locale';
import { AI_CATALOG_ITEM_LABELS } from '../constants';

const REPORT_REASON_VALUES = {
  IMMEDIATE_SECURITY_THREAT: 'IMMEDIATE_SECURITY_THREAT',
  POTENTIAL_SECURITY_THREAT: 'POTENTIAL_SECURITY_THREAT',
  EXCESSIVE_RESOURCE_USAGE: 'EXCESSIVE_RESOURCE_USAGE',
  SPAM_OR_LOW_QUALITY: 'SPAM_OR_LOW_QUALITY',
  OTHER: 'OTHER',
};

const REPORT_REASON_OPTIONS = [
  {
    value: REPORT_REASON_VALUES.IMMEDIATE_SECURITY_THREAT,
    text: s__('AICatalog|Immediate security threat'),
    help: s__('AICatalog|Contains dangerous code, exploits, or harmful actions.'),
  },
  {
    value: REPORT_REASON_VALUES.POTENTIAL_SECURITY_THREAT,
    text: s__('AICatalog|Potential security threat'),
    help: s__('AICatalog|Hypothetical or low risk security flaws that could be exploited.'),
  },
  {
    value: REPORT_REASON_VALUES.EXCESSIVE_RESOURCE_USAGE,
    text: s__('AICatalog|Excessive resource usage'),
    help: s__('AICatalog|Wasting compute or causing performance issues.'),
  },
  {
    value: REPORT_REASON_VALUES.SPAM_OR_LOW_QUALITY,
    text: s__('AICatalog|Spam or low quality'),
    help: s__('AICatalog|Frequently failing or nuisance activity.'),
  },
  {
    value: REPORT_REASON_VALUES.OTHER,
    text: s__('AICatalog|Other'),
    help: s__('AICatalog|Please describe below.'),
  },
];

const MAX_BODY_LENGTH = 1000;

export default {
  name: 'AiCatalogItemReportModal',
  components: {
    GlForm,
    GlFormCharacterCount,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormTextarea,
    GlModal,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  emits: ['submit'],
  data() {
    return {
      reason: REPORT_REASON_OPTIONS[0].value,
      body: '',
      isDirty: false,
    };
  },
  computed: {
    formId() {
      return uniqueId('ai-catalog-item-report-form-');
    },
    modal() {
      return {
        actionPrimary: {
          text: __('Submit'),
          attributes: {
            variant: 'confirm',
            type: 'submit',
            form: this.formId,
          },
        },
        actionCancel: {
          text: __('Cancel'),
        },
      };
    },
    title() {
      return sprintf(s__(`AICatalog|Report %{itemName}`), {
        itemName: this.item.name,
      });
    },
    labelDescription() {
      return sprintf(s__(`AICatalog|Why are you reporting this %{itemType}?`), {
        itemType: AI_CATALOG_ITEM_LABELS[this.item.itemType],
      });
    },
    isOtherSelected() {
      return this.reason === REPORT_REASON_VALUES.OTHER;
    },
    isBodyRequired() {
      return this.isOtherSelected;
    },
    isBodyOutOfLimit() {
      return this.body.length >= MAX_BODY_LENGTH;
    },
    isBodyMissing() {
      return this.isBodyRequired && this.body.trim().length === 0;
    },
    isBodyValid() {
      return !this.isDirty || !(this.isBodyOutOfLimit || this.isBodyMissing);
    },
    invalidFeedback() {
      if (this.isBodyOutOfLimit) {
        return s__('AICatalog|Additional details cannot exceed 1000 characters.');
      }
      if (this.isBodyMissing) {
        return s__('AICatalog|Additional details are required.');
      }

      return '';
    },
  },
  methods: {
    resetForm() {
      this.reason = REPORT_REASON_OPTIONS[0].value;
      this.isDirty = false;
      this.body = '';
    },
    handleSubmit() {
      this.isDirty = true;
      if (!this.isBodyValid) {
        return;
      }

      this.$refs.modal.hide();

      this.$emit('submit', {
        reason: this.reason,
        body: this.body.trim(),
      });
    },
    remainingCountText(count) {
      return n__('%d character remaining.', '%d characters remaining.', count);
    },
    overLimitText(count) {
      return n__('%d character over limit.', '%d characters over limit.', count);
    },
  },
  REPORT_REASON_OPTIONS,
  COUNT_TEXT_ID: 'character-count-text',
  MAX_BODY_LENGTH,
};
</script>

<template>
  <gl-modal
    ref="modal"
    modal-id="ai-catalog-item-report-modal"
    :title="title"
    :action-primary="modal.actionPrimary"
    :action-cancel="modal.actionCancel"
    @primary.prevent
    @hidden="resetForm"
  >
    <gl-form :id="formId" @submit.prevent="handleSubmit">
      <gl-form-group
        :label="s__('AICatalog|Reason for reporting')"
        :label-description="labelDescription"
        label-for="report-reason"
        :invalid-feedback="s__('AICatalog|Please select a reason for reporting.')"
      >
        <gl-form-radio-group v-model="reason">
          <gl-form-radio
            v-for="option in $options.REPORT_REASON_OPTIONS"
            :key="option.value"
            :value="option.value"
          >
            {{ option.text }}
            <template v-if="option.help" #help>
              {{ option.help }}
            </template>
          </gl-form-radio>
        </gl-form-radio-group>
      </gl-form-group>

      <gl-form-group
        :label="s__('AICatalog|Additional information')"
        label-for="report-body"
        :optional="!isBodyRequired"
        :optional-text="__('(optional)')"
        :state="isBodyValid"
        :invalid-feedback="invalidFeedback"
        data-testid="report-body"
      >
        <gl-form-textarea
          id="report-body"
          v-model="body"
          :placeholder="s__('AICatalog|Describe any relevant information for your admin')"
          :no-resize="false"
          :rows="6"
          :aria-describedby="$options.COUNT_TEXT_ID"
          data-testid="report-body-textarea"
        />
        <template #description>
          <gl-form-character-count
            :value="body"
            :limit="$options.MAX_BODY_LENGTH"
            :count-text-id="$options.COUNT_TEXT_ID"
          >
            <template #remaining-count-text="{ count }">{{ remainingCountText(count) }}</template>
            <template #over-limit-text="{ count }">{{ overLimitText(count) }}</template>
          </gl-form-character-count>
        </template>
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
