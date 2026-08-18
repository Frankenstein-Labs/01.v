<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import LicenseOverridesModal from './license_overrides_modal.vue';

export default {
  name: 'LicenseOverridesList',
  components: {
    GlButton,
    GlIcon,
    SectionLayout,
    LicenseOverridesModal,
  },
  props: {
    overrides: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['update', 'remove'],
  i18n: {
    licenseOverridesLabel: s__('ScanResultPolicy|License Overrides:'),
  },
  computed: {
    buttonText() {
      const count = this.overrides.length;

      return sprintf(
        n__('ScanResultPolicy|%{count} override', 'ScanResultPolicy|%{count} overrides', count),
        { count },
      );
    },
  },
  methods: {
    openModal() {
      this.$refs.modal.show();
    },
    onSave(updatedOverrides) {
      this.$emit('update', updatedOverrides);
    },
  },
};
</script>

<template>
  <section-layout
    :rule-label="$options.i18n.licenseOverridesLabel"
    class="gl-w-full gl-bg-default gl-pr-1 @md/panel:gl-items-center"
    label-classes="!gl-text-base !gl-w-18 @md/panel:!gl-w-18 !gl-pl-0 !gl-font-bold gl-mr-4"
    @remove="$emit('remove')"
  >
    <template #content>
      <gl-button category="primary" variant="link" class="gl-ml-2" @click="openModal">
        {{ buttonText }}
        <gl-icon name="pencil" />
      </gl-button>

      <license-overrides-modal ref="modal" :overrides="overrides" @save="onSave" />
    </template>
  </section-layout>
</template>
