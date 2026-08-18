<script>
import { GlAttributeList } from '@gitlab/ui';
import { s__ } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import CollapsibleText from './collapsible_text.vue';

const LARGE_TEXT_KEYS = {
  goal: s__('AgentArtifacts|Goal'),
  prompt_content: s__('AgentArtifacts|Prompt content'),
  response_content: s__('AgentArtifacts|Response content'),
  tool_args: s__('AgentArtifacts|Tool arguments'),
  content: s__('AgentArtifacts|Content'),
  error_message: s__('AgentArtifacts|Error message'),
  previous_error: s__('AgentArtifacts|Previous error'),
};

const humanize = (key) =>
  key
    .replace(/_/g, ' ')
    .replace(/^\w/, (char) => char.toUpperCase())
    .trim();

const formatValue = (value) =>
  value !== null && typeof value === 'object' ? JSON.stringify(value) : String(value);

const isBlank = (value) =>
  value === null || value === undefined || (typeof value === 'string' && value.trim() === '');

export default {
  name: 'DetailsSection',
  components: {
    CrudComponent,
    CollapsibleText,
    GlAttributeList,
  },
  props: {
    details: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    fields() {
      return Object.entries(this.details)
        .filter(([key, value]) => !(key in LARGE_TEXT_KEYS) && !isBlank(value))
        .map(([key, value]) => ({
          label: humanize(key),
          text: formatValue(value),
        }));
    },
    blocks() {
      return Object.entries(LARGE_TEXT_KEYS)
        .filter(([key]) => !isBlank(this.details[key]))
        .map(([key, label]) => ({ key, label, value: formatValue(this.details[key]) }));
    },
    isEmpty() {
      return this.fields.length === 0 && this.blocks.length === 0;
    },
  },
  i18n: {
    title: s__('AgentArtifacts|Details'),
    empty: s__('AgentArtifacts|No details available for this event.'),
  },
};
</script>

<template>
  <crud-component :title="$options.i18n.title" is-collapsible>
    <div v-if="isEmpty" class="gl-text-subtle" data-testid="details-empty">
      {{ $options.i18n.empty }}
    </div>
    <template v-else>
      <div v-if="fields.length" class="gl-@container">
        <gl-attribute-list layout="horizontal" :items="fields" />
      </div>

      <div
        v-for="block in blocks"
        :key="block.key"
        class="gl-mb-5"
        :data-testid="`details-block-${block.key}`"
      >
        <span class="gl-mb-2 gl-block gl-text-base gl-font-bold gl-text-strong">{{
          block.label
        }}</span>
        <div
          class="gl-rounded-base gl-border-1 gl-border-solid gl-border-section gl-bg-subtle gl-p-4"
        >
          <collapsible-text :text="block.value" />
        </div>
      </div>
    </template>
  </crud-component>
</template>
