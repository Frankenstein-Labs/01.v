<script>
import { GlFormCheckbox, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';

export default {
  KEV_FILTER_HELP_PATH: helpPagePath('user/application_security/policies/_index.md'),
  i18n: {
    label: s__('ScanResultPolicy|KEV status'),
    helpText: s__(
      'ScanResultPolicy|Only show/block vulnerabilities that %{boldStart}are%{boldEnd} being exploited.',
    ),
    kevFilterPopoverContent: s__(
      'ScanResultPolicy|Select this option if you want the policy to block the merge request (or warn the user if the policy is in warn mode) only if it includes vulnerabilities that are actively exploited according to their KEV status. %{linkStart}Learn more%{linkEnd}.',
    ),
  },
  name: 'KevFilter',
  components: {
    GlFormCheckbox,
    GlSprintf,
    PolicyPopover,
    SectionLayout,
  },
  props: {
    selected: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['select'],
  methods: {
    select(value) {
      this.$emit('select', value);
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-bg-default gl-pr-1 @md/panel:gl-items-center"
    :rule-label="$options.i18n.label"
    :show-remove-button="false"
    label-classes="!gl-text-base !gl-w-10 @md/panel:!gl-w-12 !gl-pl-0 !gl-font-bold gl-mr-4"
  >
    <template #content>
      <gl-form-checkbox class="gl-mt-3" :checked="selected" @input="select">
        <template #default>
          <gl-sprintf :message="$options.i18n.helpText">
            <template #bold="{ content }">
              <strong>{{ content }}</strong>
            </template>
          </gl-sprintf>
        </template>
      </gl-form-checkbox>

      <policy-popover
        :content="$options.i18n.kevFilterPopoverContent"
        :href="$options.KEV_FILTER_HELP_PATH"
        :title="$options.i18n.label"
        target="kev-filter-icon"
      />
    </template>
  </section-layout>
</template>
