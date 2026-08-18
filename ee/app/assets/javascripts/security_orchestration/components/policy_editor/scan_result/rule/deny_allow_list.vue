<script>
import { GlCollapsibleListbox, GlSprintf, GlButton, GlIcon } from '@gitlab/ui';
import { s__, n__, sprintf } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ALLOWED_DENIED_OPTIONS,
  ALLOWED_DENIED_LISTBOX_ITEMS,
  DENIED,
} from './scan_filters/constants';
import DenyAllowListModal from './deny_allow_list_modal.vue';

export default {
  ALLOWED_DENIED_LISTBOX_ITEMS,
  i18n: {
    denyListText: s__('ScanResultPolicy|denylist (%{licenseCount} %{licenses})'),
    allowListText: s__('ScanResultPolicy|allowlist (%{licenseCount} %{licenses})'),
    label: s__('ScanResultPolicy|License is:'),
    message: s__('ScanResultPolicy|%{listType} according to the %{buttonType}'),
  },
  name: 'DenyAllowList',
  components: {
    DenyAllowListModal,
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlSprintf,
    SectionLayout,
  },
  props: {
    selected: {
      type: String,
      required: false,
      default: DENIED,
    },
    licenses: {
      type: Array,
      required: false,
      default: () => [],
    },
    hasError: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['remove', 'select-licenses', 'select-type'],
  computed: {
    buttonText() {
      const { denyListText, allowListText } = this.$options.i18n;
      const message = this.selected === DENIED ? denyListText : allowListText;
      const licenses = n__('license', 'licenses', this.licenses.length);

      return sprintf(message, {
        licenseCount: this.licenses.length,
        licenses,
      });
    },
    toggleText() {
      return ALLOWED_DENIED_OPTIONS[this.selected] || s__('ScanResultPolicy|Select list type');
    },
  },
  methods: {
    selectListType(type) {
      this.$emit('select-type', type);
    },
    showModal() {
      this.$refs.modal.showModalWindow();
    },
    selectLicenses(licenses) {
      this.$emit('select-licenses', licenses);
    },
  },
};
</script>

<template>
  <section-layout
    :rule-label="$options.i18n.label"
    class="gl-w-full gl-bg-default gl-pr-1 @md/panel:gl-items-center"
    :class="{ 'gl-border gl-border-red-400': hasError }"
    label-classes="!gl-text-base !gl-w-10 @md/panel:!gl-w-12 !gl-pl-0 !gl-font-bold gl-mr-4"
    @remove="$emit('remove')"
  >
    <template #content>
      <gl-sprintf :message="$options.i18n.message">
        <template #listType>
          <gl-collapsible-listbox
            :selected="selected"
            :items="$options.ALLOWED_DENIED_LISTBOX_ITEMS"
            :toggle-text="toggleText"
            @select="selectListType"
          />
        </template>
        <template #buttonType>
          <gl-button category="primary" variant="link" @click="showModal">
            {{ buttonText }}
            <gl-icon name="pencil" />
          </gl-button>
        </template>
      </gl-sprintf>

      <deny-allow-list-modal
        ref="modal"
        :licenses="licenses"
        :list-type="selected"
        @select-licenses="selectLicenses"
      />
    </template>
  </section-layout>
</template>
