<script>
import { GlFormCheckbox, GlFormGroup, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';

export default {
  name: 'DuoAuditEventStorageForm',
  i18n: {
    sectionTitle: s__('AiPowered|AI audit event storage'),
    checkboxLabel: s__('AiPowered|Store AI audit events'),
    checkboxHelpText: s__(
      'AiPowered|When you turn on this setting, GitLab stores new AI audit events to the database or ClickHouse. Real-time streaming of AI audit events is not affected.',
    ),
    disabledTooltip: s__('AiPowered|This setting only applies when GitLab Duo is available.'),
  },
  components: {
    GlFormCheckbox,
    GlFormGroup,
    CascadingLockIcon,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: ['aiAuditEventsStorageEnabled', 'aiAuditEventsStorageCascadingSettings'],
  props: {
    disabledCheckbox: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      auditEventsStorageEnabled: this.aiAuditEventsStorageEnabled,
    };
  },
  computed: {
    cascadingSettingsData() {
      return this.aiAuditEventsStorageCascadingSettings || {};
    },
    showCascadingIcon() {
      return Boolean(Object.keys(this.cascadingSettingsData).length);
    },
    isLocked() {
      return Boolean(
        this.cascadingSettingsData.lockedByAncestor ||
        this.cascadingSettingsData.lockedByApplicationSetting,
      );
    },
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.auditEventsStorageEnabled);
    },
  },
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle">
      <div class="gl-flex gl-items-center gl-gap-2">
        <gl-form-checkbox
          v-model="auditEventsStorageEnabled"
          data-testid="ai-audit-events-storage-checkbox"
          :disabled="disabledCheckbox || isLocked"
          @change="checkboxChanged"
        >
          <span
            id="ai-audit-events-storage-checkbox-label"
            v-tooltip="disabledCheckbox ? $options.i18n.disabledTooltip : ''"
            >{{ $options.i18n.checkboxLabel }}</span
          >
          <template #help>
            {{ $options.i18n.checkboxHelpText }}
          </template>
        </gl-form-checkbox>
        <cascading-lock-icon
          v-if="showCascadingIcon"
          data-testid="ai-audit-events-storage-cascading-lock-icon"
          :is-locked-by-group-ancestor="cascadingSettingsData.lockedByAncestor"
          :is-locked-by-application-settings="cascadingSettingsData.lockedByApplicationSetting"
          :ancestor-namespace="cascadingSettingsData.ancestorNamespace"
        />
      </div>
    </gl-form-group>
  </div>
</template>
