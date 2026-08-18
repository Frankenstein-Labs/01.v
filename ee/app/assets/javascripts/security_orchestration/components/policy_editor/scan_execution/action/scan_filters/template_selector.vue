<script>
import { GlCollapsibleListbox, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import {
  DEFAULT_TEMPLATE,
  LATEST_TEMPLATE,
  NONVERSIONED_TEMPLATES,
  VERSIONED_TEMPLATES,
} from './constants';

const VERSIONED_TEMPLATE_TYPES = Object.keys(VERSIONED_TEMPLATES);

export default {
  name: 'TemplateSelectorEE',
  i18n: {
    label: s__('SecurityOrchestration|Security job template'),
    defaultTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template edition to be enforced. The default template is stable, but may not have all the features of the latest template.',
    ),
    latestTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template edition to be enforced. The latest edition may introduce breaking changes.',
    ),
    versionedTemplateInformation: s__(
      'SecurityOrchestration|CI/CD template version to be enforced. Specific versions offer stability but may not include the latest features.',
    ),
  },
  components: {
    GlCollapsibleListbox,
    HelpIcon,
    SectionLayout,
  },
  directives: {
    GlTooltip,
  },
  props: {
    selected: {
      type: String,
      required: false,
      default: DEFAULT_TEMPLATE,
    },
    scanType: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['input', 'remove'],
  computed: {
    supportsVersionedTemplates() {
      return VERSIONED_TEMPLATE_TYPES.includes(this.scanType);
    },
    availableOptions() {
      if (this.supportsVersionedTemplates) {
        return VERSIONED_TEMPLATES[this.scanType];
      }

      return NONVERSIONED_TEMPLATES;
    },
    tooltipMessage() {
      if (
        this.supportsVersionedTemplates &&
        this.selected !== LATEST_TEMPLATE &&
        this.selected !== DEFAULT_TEMPLATE
      ) {
        return this.$options.i18n.versionedTemplateInformation;
      }

      return this.selected === LATEST_TEMPLATE
        ? this.$options.i18n.latestTemplateInformation
        : this.$options.i18n.defaultTemplateInformation;
    },
  },
  methods: {
    toggleValue(value) {
      if (value !== DEFAULT_TEMPLATE) {
        this.$emit('input', { template: value });
      } else {
        this.$emit('remove');
      }
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-w-full gl-bg-default"
    content-classes="gl-justify-between"
    :show-remove-button="false"
  >
    <template #selector>
      <label class="gl-mb-0 gl-mr-4" for="policy-template" :title="$options.i18n.label">
        {{ $options.i18n.label }}
      </label>
    </template>

    <template #content>
      <div class="gl-flex gl-grow-2 gl-items-center">
        <gl-collapsible-listbox
          id="policy-template"
          :items="availableOptions"
          :selected="selected"
          @select="toggleValue"
        />
        <help-icon v-gl-tooltip :title="tooltipMessage" class="gl-ml-3" />
      </div>
    </template>
  </section-layout>
</template>
