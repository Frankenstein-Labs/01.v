<script>
import { GlFormCheckbox, GlLink, GlTooltipDirective, GlFormGroup } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { AI_USAGE_DATA_COLLECTION_DOCS_URL } from '../constants';

export default {
  name: 'AiUsageDataCollectionForm',
  i18n: {
    sectionTitle: s__('AiPowered|Data collection'),
    checkboxLabel: s__('AiPowered|Collect usage data'),
    checkboxHelpText: s__(
      'AiPowered|Allow GitLab to collect prompts, AI responses, and metadata from user interactions with GitLab Duo. This data helps improve service quality and is not used to train models.',
    ),
    learnMore: __('Which data is collected'),
    disabledTooltip: s__('AiPowered|This setting only applies when GitLab Duo is available.'),
  },
  components: {
    GlFormCheckbox,
    GlLink,
    GlFormGroup,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: ['aiUsageDataCollectionEnabled'],
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
      aiUsageDataCollection: this.aiUsageDataCollectionEnabled,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.aiUsageDataCollection);
    },
  },
  AI_USAGE_DATA_COLLECTION_DOCS_URL,
};
</script>
<template>
  <div>
    <gl-form-group :label="$options.i18n.sectionTitle">
      <gl-form-checkbox
        v-model="aiUsageDataCollection"
        data-testid="ai-usage-data-collection-checkbox"
        :disabled="disabledCheckbox"
        @change="checkboxChanged"
      >
        <span
          id="ai-usage-data-collection-checkbox-label"
          v-tooltip="disabledCheckbox ? $options.i18n.disabledTooltip : ''"
          >{{ $options.i18n.checkboxLabel }}</span
        >
        <template #help>
          {{ $options.i18n.checkboxHelpText }}
          <gl-link
            data-testid="ai-usage-data-collection-link"
            :href="$options.AI_USAGE_DATA_COLLECTION_DOCS_URL"
            target="_blank"
          >
            {{ $options.i18n.learnMore }}</gl-link
          >?
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
