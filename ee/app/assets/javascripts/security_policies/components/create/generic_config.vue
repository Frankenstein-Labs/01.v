<script>
import {
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlFormTextarea,
  GlTableLite,
  GlToggle,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import MultiBadgeSelector from './multi_badge_selector.vue';

export default {
  name: 'GenericConfig',
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlFormTextarea,
    GlTableLite,
    GlToggle,
    MultiBadgeSelector,
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
    { key: 'label', tdClass: 'gl-pl-2 gl-text-sm gl-text-secondary !gl-border-0' },
  ],
  i18n: {
    days: s__('SecurityOrchestration|days'),
    slaDescription: s__(
      'SecurityOrchestration|Most restrictive SLA wins when multiple policies match',
    ),
    selectPlaceholder: s__('SecurityOrchestration|Select...'),
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
  methods: {
    update(key, val) {
      this.$emit('input', { ...this.value, [key]: val });
    },
    updateMatrix(key, severity, days) {
      this.update(key, { ...(this.value[key] || {}), [severity]: days });
    },
    segmentButtonClass(fieldKey, optId, firstOptId) {
      return (this.value[fieldKey] || firstOptId) === optId
        ? ['gl-border-2', 'gl-border-blue-500', 'gl-font-bold']
        : ['gl-border-default'];
    },
    slaInputValue(fieldKey, sev) {
      return (this.value[fieldKey] || {})[sev] || '';
    },
    multiBadgeValue(fieldKey) {
      return this.value[fieldKey] || [];
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-4">
    <template v-for="field in fields">
      <gl-toggle
        v-if="field.type === 'toggle'"
        :key="field.key"
        :value="value[field.key] || false"
        :label="field.label"
        :name="field.key"
        @change="update(field.key, $event)"
      />
      <div v-else-if="field.type === 'sla_matrix'" :key="field.key">
        <p class="gl-mb-2 gl-text-sm gl-font-bold">{{ field.label }}</p>
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
        <p class="gl-mb-0 gl-text-sm gl-text-secondary">{{ $options.i18n.slaDescription }}</p>
      </div>
      <gl-form-group
        v-else
        :key="field.key"
        :label="field.label"
        :description="field.description"
        class="gl-mb-0"
      >
        <multi-badge-selector
          v-if="field.type === 'multi_badge'"
          :options="field.options"
          :value="multiBadgeValue(field.key)"
          @input="update(field.key, $event)"
        />
        <gl-form-select
          v-else-if="field.type === 'select'"
          :value="value[field.key] || ''"
          @change="update(field.key, $event)"
        >
          <option value="">{{ $options.i18n.selectPlaceholder }}</option>
          <option v-for="opt in field.options" :key="opt.id" :value="opt.id">
            {{ opt.label }}
          </option>
        </gl-form-select>
        <gl-form-textarea
          v-else-if="field.type === 'textarea'"
          :value="value[field.key] || ''"
          :placeholder="field.placeholder"
          @input="update(field.key, $event)"
        />
        <div v-else-if="field.type === 'segment'" class="gl-flex gl-gap-2">
          <gl-button
            v-for="opt in field.options"
            :key="opt.id"
            class="gl-border gl-cursor-pointer gl-rounded-base gl-px-3 gl-py-1 gl-text-sm"
            :class="segmentButtonClass(field.key, opt.id, field.options[0].id)"
            @click="update(field.key, opt.id)"
          >
            {{ opt.label }}
          </gl-button>
        </div>
        <gl-form-textarea
          v-else-if="field.type === 'code'"
          :value="value[field.key] || ''"
          :placeholder="field.placeholder"
          :rows="10"
          :maxlength="field.maxLength"
          class="gl-font-monospace gl-text-sm"
          spellcheck="false"
          @input="update(field.key, $event)"
        />
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
