<script>
import { GlBadge, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';

export default {
  name: 'ScanSettingsToggle',
  i18n: {
    label: s__('ScanExecutionPolicy|Ignore default CI configuration for before/after script'),
  },
  components: {
    GlBadge,
    GlToggle,
    SectionLayout,
  },
  props: {
    selected: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['input', 'remove'],
  methods: {
    handleChange(value) {
      if (value) {
        this.$emit('input', { scan_settings: { ignore_default_before_after_script: true } });
      } else {
        this.$emit('remove');
      }
    },
  },
};
</script>

<template>
  <section-layout class="gl-w-full gl-bg-default" :show-remove-button="false">
    <template #content>
      <div class="gl-flex gl-items-center">
        <gl-toggle
          :value="selected"
          :label="$options.i18n.label"
          label-position="hidden"
          @change="handleChange"
        />
        <div class="gl-ml-3">
          <span class="gl-font-bold">{{ $options.i18n.label }}</span>
          <gl-badge class="gl-ml-3" size="sm" variant="info">
            {{ __('New') }}
          </gl-badge>
          <p class="gl-mb-0 gl-mt-1 gl-text-subtle">
            {{
              s__(
                'ScanExecutionPolicy|Prevents project before script and after script from interfering with scan execution.',
              )
            }}
          </p>
        </div>
      </div>
    </template>
  </section-layout>
</template>
