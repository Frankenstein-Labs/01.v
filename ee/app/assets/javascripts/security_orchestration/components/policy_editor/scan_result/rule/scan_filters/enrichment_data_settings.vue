<script>
import { GlFormRadioGroup, GlFormRadio } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import { ENRICHMENT_DATA_ACTIONS, ENRICHMENT_DATA_ACTION_OPTIONS } from './constants';
import { isValidEnrichmentDataAction } from './utils';

export default {
  ENRICHMENT_DATA_ACTION_OPTIONS,
  HELP_PATH: helpPagePath('user/application_security/policies/_index.md'),
  i18n: {
    label: s__('ScanResultPolicy|Exception settings'),
  },
  name: 'EnrichmentDataSettings',
  components: {
    GlFormRadioGroup,
    GlFormRadio,
    PolicyPopover,
    SectionLayout,
  },
  props: {
    selectedAction: {
      type: String,
      required: false,
      default: ENRICHMENT_DATA_ACTIONS.BLOCK,
      validator: isValidEnrichmentDataAction,
    },
  },
  emits: ['change'],
  methods: {
    onChange(value) {
      this.$emit('change', value);
    },
    popoverTarget(option) {
      return `enrichment-data-${option.value}-icon`;
    },
  },
};
</script>

<template>
  <div>
    <h5 class="gl-m-0 gl-mt-4 gl-bg-white gl-px-5 gl-py-4">{{ $options.i18n.label }}</h5>

    <section-layout
      class="gl-w-full gl-bg-default gl-pr-1 @md/panel:gl-items-center"
      :show-remove-button="false"
      label-classes="!gl-text-base !gl-w-10 @md/panel:!gl-w-12 !gl-pl-0 !gl-font-bold gl-mr-4"
    >
      <template #content>
        <gl-form-radio-group
          :checked="selectedAction"
          data-testid="enrichment-data-radio-group"
          @change="onChange"
        >
          <gl-form-radio
            v-for="option in $options.ENRICHMENT_DATA_ACTION_OPTIONS"
            :key="option.value"
            :value="option.value"
          >
            <span class="gl-inline-flex gl-items-center gl-gap-2">
              {{ option.text }}
              <policy-popover
                :content="option.popoverContent"
                :href="$options.HELP_PATH"
                :title="option.text"
                :target="popoverTarget(option)"
              />
            </span>
          </gl-form-radio>
        </gl-form-radio-group>
      </template>
    </section-layout>
  </div>
</template>
