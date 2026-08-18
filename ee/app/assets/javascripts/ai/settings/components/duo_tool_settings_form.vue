<script>
import { GlFormGroup, GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'DuoToolSettingsForm',
  components: {
    GlFormGroup,
    GlFormCheckbox,
  },
  props: {
    isMcpEnabled: {
      type: Boolean,
      required: true,
    },
    showMcp: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['mcp-change'],
  methods: {
    checkboxChanged(value) {
      this.$emit('mcp-change', value);
    },
  },
};
</script>
<template>
  <div v-if="showMcp" class="gl-flex gl-flex-col">
    <h2 class="gl-heading-3 gl-mb-2 gl-mt-6" data-testid="tools-subsection-header">
      {{ s__('AiPowered|Tools') }}
    </h2>
    <p class="gl-text-subtle" data-testid="tools-subsection-description">
      {{ s__('AiPowered|Interact directly with GitLab and perform common GitLab operations.') }}
    </p>

    <gl-form-group :label="s__('DuoWorkflowSettings|External MCP tools')">
      <gl-form-checkbox
        :checked="isMcpEnabled"
        data-testid="enable-duo-workflow-mcp-enabled-checkbox"
        name="namespace[ai_settings_attributes][duo_workflow_mcp_enabled]"
        @change="checkboxChanged"
      >
        <span id="enable-duo-workflow-mcp-enabled-checkbox-label">{{
          s__('DuoWorkflowSettings|Allow external MCP tools')
        }}</span>
        <template #help>
          {{ s__('DuoWorkflowSettings|Allow the IDE to access external MCP tools.') }}
        </template>
      </gl-form-checkbox>
    </gl-form-group>
  </div>
</template>
