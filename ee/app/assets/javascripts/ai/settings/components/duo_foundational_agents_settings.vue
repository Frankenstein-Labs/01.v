<script>
import {
  GlLink,
  GlSprintf,
  GlFormRadioGroup,
  GlFormRadio,
  GlFormGroup,
  GlTableLite,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__ } from '~/locale';

export const FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES = {
  enabled: 'enabled',
  disabled: 'disabled',
  default: 'use_default',
};

export default {
  name: 'FoundationalAgentsSettings',
  tableHeaderFields: [
    {
      key: 'name',
      label: s__('FoundationalAgents|Agent'),
    },
    {
      key: 'availability',
      id: 'agent-availability',
      label: s__('FoundationalAgents|Availability'),
      thClass: 'gl-w-1/2',
      tdClass: 'gl-w-1/2',
    },
  ],
  components: {
    GlFormRadioGroup,
    GlFormRadio,
    GlFormGroup,
    GlLink,
    GlSprintf,
    GlTableLite,
    GlCollapsibleListbox,
  },
  inject: ['showFoundationalAgentsPerAgentAvailability'],
  props: {
    foundationalAgentsEnabled: {
      type: Boolean,
      required: true,
    },
    agentStatuses: {
      type: Array,
      required: true,
    },
    readOnly: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change', 'agent-toggle'],
  computed: {
    enabledInput: {
      get() {
        return this.foundationalAgentsEnabled;
      },
      set(val) {
        this.$emit('change', val);
      },
    },
    showAgentsTable() {
      return this.showFoundationalAgentsPerAgentAvailability && this.agentStatuses.length;
    },
    sectionTitle() {
      if (this.showFoundationalAgentsPerAgentAvailability) {
        return s__('FoundationalAgents|Default availability');
      }

      return s__('FoundationalAgents|Foundational agents');
    },
    description() {
      if (this.showFoundationalAgentsPerAgentAvailability) {
        return s__(
          'FoundationalAgents|Control whether foundational agents are available by default.',
        );
      }

      return s__(
        'FoundationalAgents|Control whether foundational agents are available by default.',
      );
    },
    enabledLabel() {
      if (this.showFoundationalAgentsPerAgentAvailability) return s__('FoundationalAgents|On');

      return s__('FoundationalAgents|On');
    },
    disabledLabel() {
      if (this.showFoundationalAgentsPerAgentAvailability) return s__('FoundationalAgents|Off');

      return s__('FoundationalAgents|Off');
    },
    onByDefaultHelpText() {
      if (!this.showFoundationalAgentsPerAgentAvailability)
        return s__(
          'FoundationalAgents|Foundational agents are available for projects in this group.',
        );

      return '';
    },
    offByDefaultHelpText() {
      if (!this.showFoundationalAgentsPerAgentAvailability) {
        return s__('FoundationalAgents|Foundational agents are not available.');
      }
      return '';
    },
    availabilityOptions() {
      const defaultText = this.foundationalAgentsEnabled
        ? s__('FoundationalAgents|Use default (On)')
        : s__('FoundationalAgents|Use default (Off)');

      return [
        {
          value: FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.enabled,
          text: s__('FoundationalAgents|On'),
        },
        {
          value: FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.disabled,
          text: s__('FoundationalAgents|Off'),
        },
        {
          value: FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.default,
          text: defaultText,
        },
      ];
    },
  },
  methods: {
    getSelectedOption(value) {
      if (value === null) return FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.default;

      return value
        ? FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.enabled
        : FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.disabled;
    },
    getToggleText(value) {
      const selectedValue = this.getSelectedOption(value);
      const option = this.availabilityOptions.find((opt) => opt.value === selectedValue);
      return option?.text || '';
    },
    getEnabledValue(optionValue) {
      switch (optionValue) {
        case FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.enabled:
          return true;
        case FOUNDATIONAL_AGENTS_AVAILABILITY_VALUES.disabled:
          return false;
        default:
          return null;
      }
    },
    toggleAgent(reference, value) {
      const agentStatuses = this.agentStatuses.map((agent) => ({
        ...agent,
        enabled: agent.reference === reference ? this.getEnabledValue(value) : agent.enabled,
      }));
      this.$emit('agent-toggle', agentStatuses);
    },
  },
  foundationalAgentsHelpPath: helpPagePath(
    'user/duo_agent_platform/agents/foundational_agents/_index.md',
  ),
};
</script>
<template>
  <div>
    <h2 class="gl-heading-3 gl-mb-2 gl-mt-6" data-testid="agents-subsection-header">
      {{ s__('AiPowered|Agents') }}
    </h2>
    <p class="gl-text-subtle" data-testid="agents-subsection-description">
      {{ s__('AiPowered|Accomplish specific tasks and get answers to complex questions.') }}
    </p>
    <template v-if="showFoundationalAgentsPerAgentAvailability">
      <h3 class="gl-heading-4 gl-mb-2">{{ s__('FoundationalAgents|Foundational agents') }}</h3>
      <gl-sprintf
        :message="
          s__(
            'FoundationalAgents|When turned on, foundational agents are available for projects in this group. %{linkStart}What are foundational agents%{linkEnd}?',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.foundationalAgentsHelpPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
    <gl-form-group :label="sectionTitle" class="gl-mt-5" :disabled="readOnly">
      <template #label-description>
        <gl-sprintf :message="description">
          <template #link="{ content }">
            <gl-link :href="$options.foundationalAgentsHelpPath">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>

      <gl-form-radio-group v-model="enabledInput">
        <gl-form-radio :value="true">
          {{ enabledLabel }}

          <template #help>
            {{ onByDefaultHelpText }}
          </template>
        </gl-form-radio>

        <gl-form-radio :value="false">
          {{ disabledLabel }}

          <template #help>
            {{ offByDefaultHelpText }}
          </template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>
    <gl-form-group
      v-if="showAgentsTable"
      :label="s__('FoundationalAgents|Availability settings')"
      :label-description="
        s__('FoundationalAgents|Control the availability of each foundational agent individually.')
      "
      class="gl-mt-4"
    >
      <gl-table-lite
        :fields="$options.tableHeaderFields"
        :items="agentStatuses"
        data-testid="foundational-agents-table"
        class="gl-border gl-rounded-lg gl-border-section gl-bg-subtle"
        thead-tr-class="gl-bg-section"
        responsive
        borderless
      >
        <template #cell(name)="{ item }">
          <span :class="['@md/panel:gl-pt-3', { 'gl-text-disabled': readOnly }]">{{
            item.name
          }}</span>
        </template>
        <template #cell(availability)="{ item }">
          <gl-collapsible-listbox
            block
            aria-labelledby="agent-availability"
            category="primary"
            class="gl-max-w-34"
            :toggle-text="getToggleText(item.enabled)"
            :selected="getSelectedOption(item.enabled)"
            :items="availabilityOptions"
            :disabled="readOnly"
            :data-testid="`agent-${item.reference}-dropdown`"
            @select="toggleAgent(item.reference, $event)"
          />
        </template>
      </gl-table-lite>
    </gl-form-group>
  </div>
</template>
