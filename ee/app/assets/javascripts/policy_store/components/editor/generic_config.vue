<script>
import {
  GlButton,
  GlFormCheckbox,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlFormTextarea,
  GlIcon,
  GlTableLite,
  GlToggle,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  FIELD_TYPE_CHECKBOX,
  FIELD_TYPE_CODE,
  FIELD_TYPE_MULTI_BADGE,
  FIELD_TYPE_SEGMENT,
  FIELD_TYPE_SELECT,
  FIELD_TYPE_SLA_MATRIX,
  FIELD_TYPE_TEXTAREA,
  FIELD_TYPE_TOGGLE,
} from './constants';
import MultiBadgeSelector from './multi_badge_selector.vue';
import RegoTemplatesModal from './rego_templates_modal.vue';

export default {
  name: 'GenericConfig',
  components: {
    GlButton,
    GlFormCheckbox,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlFormTextarea,
    GlIcon,
    GlTableLite,
    GlToggle,
    MultiBadgeSelector,
    RegoTemplatesModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  SLA_ITEMS: [
    { severity: 'critical' },
    { severity: 'high' },
    { severity: 'medium' },
    { severity: 'low' },
  ],
  SLA_FIELDS: [
    { key: 'severity', tdClass: 'gl-w-20 gl-py-1 gl-pr-4 gl-text-sm gl-capitalize !gl-border-0' },
    { key: 'input', tdClass: '!gl-border-0' },
    { key: 'label', tdClass: 'gl-pl-2 gl-text-sm gl-text-subtle !gl-border-0' },
  ],
  i18n: {
    days: s__('PolicyStore|days'),
    slaDescription: s__('PolicyStore|Most restrictive SLA wins when multiple policies match'),
    selectPlaceholder: s__('PolicyStore|Select...'),
    browseTemplates: s__('PolicyStore|Browse templates'),
  },
  props: {
    fields: {
      type: Array,
      required: true,
    },
    value: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['input'],
  data() {
    return { templatesModalKey: null };
  },
  created() {
    // Seed every field that declares a default, so the value is persisted even when the
    // user never touches the control. Without this, `toggleValue` would show a default as
    // checked while the key stayed absent from the saved payload.
    //
    // Emitted as a single update: `update` rebuilds the object from `this.value`, so
    // seeding field by field would drop every default but the last.
    const defaults = this.fields.reduce((acc, field) => {
      const isUnset = this.value[field.key] == null;

      return field.default !== undefined && isUnset ? { ...acc, [field.key]: field.default } : acc;
    }, {});

    if (Object.keys(defaults).length) {
      this.$emit('input', { ...this.value, ...defaults });
    }
  },
  methods: {
    isToggle(field) {
      return field.type === FIELD_TYPE_TOGGLE;
    },
    isCheckbox(field) {
      return field.type === FIELD_TYPE_CHECKBOX;
    },
    isSlaMatrix(field) {
      return field.type === FIELD_TYPE_SLA_MATRIX;
    },
    isCode(field) {
      return field.type === FIELD_TYPE_CODE;
    },
    isMultiBadge(field) {
      return field.type === FIELD_TYPE_MULTI_BADGE;
    },
    isSelect(field) {
      return field.type === FIELD_TYPE_SELECT;
    },
    isTextarea(field) {
      return field.type === FIELD_TYPE_TEXTAREA;
    },
    isSegment(field) {
      return field.type === FIELD_TYPE_SEGMENT;
    },
    update(key, val) {
      this.$emit('input', { ...this.value, [key]: val });
    },
    updateMatrix(key, severity, days) {
      this.update(key, { ...(this.value[key] || {}), [severity]: days });
    },
    isSegmentSelected(field, optId) {
      return (this.value[field.key] || field.options[0].id) === optId;
    },
    slaInputValue(fieldKey, sev) {
      return (this.value[fieldKey] || {})[sev] || '';
    },
    multiBadgeValue(fieldKey) {
      return this.value[fieldKey] || [];
    },
    toggleValue(field) {
      const val = this.value[field.key];
      return val == null ? field.default || false : val;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-4">
    <template v-for="field in fields">
      <gl-toggle
        v-if="isToggle(field)"
        :key="field.key"
        :value="toggleValue(field)"
        :label="field.label"
        :name="field.key"
        @change="update(field.key, $event)"
      />
      <gl-form-checkbox
        v-else-if="isCheckbox(field)"
        :key="field.key"
        :checked="toggleValue(field)"
        @change="update(field.key, $event)"
      >
        {{ field.label }}
      </gl-form-checkbox>
      <div v-else-if="isSlaMatrix(field)" :key="field.key">
        <p class="gl-mb-2 gl-text-sm gl-font-semibold">{{ field.label }}</p>
        <gl-table-lite
          :fields="$options.SLA_FIELDS"
          :items="$options.SLA_ITEMS"
          thead-class="gl-hidden"
          class="gl-mb-1"
          table-class="gl-w-full"
        >
          <template #cell(severity)="{ item }">
            {{ item.severity }}
          </template>
          <template #cell(input)="{ item }">
            <gl-form-input
              type="number"
              :value="slaInputValue(field.key, item.severity)"
              :placeholder="$options.i18n.days"
              class="gl-w-24"
              @input="updateMatrix(field.key, item.severity, $event)"
            />
          </template>
          <template #cell(label)>
            {{ $options.i18n.days }}
          </template>
        </gl-table-lite>
        <p class="gl-mb-0 gl-text-sm gl-text-subtle">{{ $options.i18n.slaDescription }}</p>
      </div>
      <div v-else-if="isCode(field)" :key="field.key">
        <div class="gl-mb-2 gl-flex gl-items-center gl-justify-between">
          <label class="gl-mb-0 gl-font-semibold">
            {{ field.label }}<span v-if="field.required" class="gl-text-danger"> *</span>
            <gl-icon
              v-if="field.helpText"
              v-gl-tooltip
              name="question-o"
              :size="12"
              :title="field.helpText"
              class="gl-ml-1 gl-text-subtle"
            />
          </label>
          <gl-button
            category="secondary"
            variant="default"
            size="small"
            icon="documents"
            @click="templatesModalKey = field.key"
          >
            {{ $options.i18n.browseTemplates }}
          </gl-button>
        </div>
        <gl-form-textarea
          :value="value[field.key] || ''"
          :placeholder="field.placeholder"
          :rows="10"
          :maxlength="field.maxLength"
          class="gl-border gl-rounded-lg gl-border-subtle gl-bg-subtle gl-font-monospace gl-text-sm"
          spellcheck="false"
          @input="update(field.key, $event)"
        />
        <rego-templates-modal
          :visible="templatesModalKey === field.key"
          @select="update(field.key, $event)"
          @hide="templatesModalKey = null"
        />
      </div>
      <gl-form-group v-else :key="field.key" :description="field.description" class="gl-mb-0">
        <template #label>
          {{ field.label }}<span v-if="field.required" class="gl-text-danger"> *</span>
          <gl-icon
            v-if="field.helpText"
            v-gl-tooltip
            name="question-o"
            :size="12"
            :title="field.helpText"
            class="gl-ml-1 gl-text-subtle"
          />
        </template>
        <multi-badge-selector
          v-if="isMultiBadge(field)"
          :options="field.options"
          :value="multiBadgeValue(field.key)"
          @input="update(field.key, $event)"
        />
        <gl-form-select
          v-else-if="isSelect(field)"
          :value="value[field.key] || ''"
          @change="update(field.key, $event)"
        >
          <option value="">{{ field.placeholder || $options.i18n.selectPlaceholder }}</option>
          <option v-for="opt in field.options" :key="opt.id" :value="opt.id">
            {{ opt.label }}
          </option>
        </gl-form-select>
        <gl-form-textarea
          v-else-if="isTextarea(field)"
          :value="value[field.key] || ''"
          :placeholder="field.placeholder"
          @input="update(field.key, $event)"
        />
        <div v-else-if="isSegment(field)" class="gl-flex gl-gap-2">
          <gl-button
            v-for="opt in field.options"
            :key="opt.id"
            size="small"
            :selected="isSegmentSelected(field, opt.id)"
            @click="update(field.key, opt.id)"
          >
            {{ opt.label }}
          </gl-button>
        </div>
        <gl-form-input
          v-else
          :value="value[field.key] || ''"
          :placeholder="field.placeholder"
          @input="update(field.key, $event)"
        />
      </gl-form-group>
    </template>
  </div>
</template>
