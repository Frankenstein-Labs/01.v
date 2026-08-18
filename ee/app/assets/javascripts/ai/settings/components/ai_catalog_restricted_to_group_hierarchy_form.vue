<script>
import { GlFormCheckbox, GlFormGroup, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';

export default {
  name: 'AiCatalogRestrictedToGroupHierarchyForm',
  i18n: {
    sectionTitle: s__('AICatalog|AI Catalog'),
    checkboxLabel: s__('AICatalog|Restrict the AI Catalog to this group'),
    checkboxHelpText: s__(
      'AICatalog|In the AI Catalog, show only agents and flows that belong to projects in this group hierarchy or foundational agents and flows. Agents and flows from outside this group hierarchy are hidden and cannot be turned on or used.',
    ),
    disabledTooltip: s__('AiPowered|This setting only applies when GitLab Duo is available.'),
  },
  components: {
    GlFormCheckbox,
    GlFormGroup,
    GlLink,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  inject: ['aiCatalogRestrictedToGroupHierarchy'],
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
      restrictedToGroupHierarchy: this.aiCatalogRestrictedToGroupHierarchy,
    };
  },
  methods: {
    checkboxChanged() {
      this.$emit('change', this.restrictedToGroupHierarchy);
    },
  },
  aiCatalogHelpPath: helpPagePath('user/duo_agent_platform/ai_catalog'),
};
</script>
<template>
  <gl-form-group :label="$options.i18n.sectionTitle">
    <gl-form-checkbox
      v-model="restrictedToGroupHierarchy"
      data-testid="ai-catalog-restricted-to-group-hierarchy-checkbox"
      :disabled="disabledCheckbox"
      @change="checkboxChanged"
    >
      <span v-tooltip="disabledCheckbox ? $options.i18n.disabledTooltip : ''">{{
        $options.i18n.checkboxLabel
      }}</span>
      <template #help>
        {{ $options.i18n.checkboxHelpText }}
        <gl-link
          data-testid="ai-catalog-restricted-to-group-hierarchy-link"
          :href="$options.aiCatalogHelpPath"
          target="_blank"
          >{{ s__('AICatalog|What is the AI Catalog') }}</gl-link
        >?
      </template>
    </gl-form-checkbox>
  </gl-form-group>
</template>
