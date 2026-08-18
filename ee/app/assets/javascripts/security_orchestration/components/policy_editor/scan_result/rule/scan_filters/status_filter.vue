<script>
import { GlCollapsibleListbox, GlIcon, GlPopover, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { groupSelectedVulnerabilityStates } from '../../lib';
import {
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  APPROVAL_VULNERABILITY_STATE_GROUPS,
  APPROVAL_VULNERABILITY_STATES,
  DEFAULT_VULNERABILITY_STATES,
} from './constants';

export default {
  APPROVAL_VULNERABILITY_STATE_GROUPS,
  APPROVAL_VULNERABILITY_STATES,
  PREVIOUSLY_EXISTING,
  POPOVER_TARGET_ID: 'previously-existing-tooltip-target',
  i18n: {
    headerText: __('Choose an option'),
    vulnerabilityStates: s__('ScanResultPolicy|vulnerability states'),
    previouslyExistingTooltip: s__(
      "ScanResultPolicy|%{boldStart}Warning:%{boldEnd} Using this status in strictly enforced policies can block merge requests even if there are no new vulnerabilities found in the latest scan. It's recommended that you use warn mode only with this status.",
    ),
  },
  name: 'StatusFilterEE',
  components: {
    RuleMultiSelect,
    SectionLayout,
    GlCollapsibleListbox,
    GlIcon,
    GlPopover,
    GlSprintf,
  },
  props: {
    selected: {
      type: Array,
      required: false,
      default: () => [],
    },
    filter: {
      type: String,
      required: false,
      default: NEWLY_DETECTED,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    showRemoveButton: {
      type: Boolean,
      required: false,
      default: true,
    },
    label: {
      type: String,
      required: false,
      default: s__('ScanResultPolicy|Status is:'),
    },
    labelClasses: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['change-group', 'input', 'remove'],
  data() {
    return {
      filters: groupSelectedVulnerabilityStates(this.selected)[this.filter],
      selectedFilter: this.filter,
    };
  },
  computed: {
    vulnerabilityStateGroups() {
      return Object.entries(APPROVAL_VULNERABILITY_STATE_GROUPS).map(([value, text]) => ({
        value,
        text,
      }));
    },
    showPreviouslyExistingTooltip() {
      return this.selectedFilter === PREVIOUSLY_EXISTING;
    },
  },
  watch: {
    selected(newSelected) {
      this.filters = groupSelectedVulnerabilityStates(newSelected)[this.filter];
    },
  },
  methods: {
    remove() {
      this.$emit('remove', this.filter);
    },
    selectVulnerabilityStateGroup(value) {
      this.selectedFilter = value;
      this.filters = value === NEWLY_DETECTED ? DEFAULT_VULNERABILITY_STATES : [];
      this.$emit('change-group', value);
    },
    emitVulnerabilityStates(value) {
      this.filters = value;
      const selectedStates = Object.values(this.filters).flatMap((states) => states);
      this.$emit('input', selectedStates);
    },
  },
};
</script>

<template>
  <section-layout
    :key="filter"
    class="gl-w-full gl-bg-default gl-pr-2"
    :rule-label="label"
    :label-classes="labelClasses"
    :show-remove-button="showRemoveButton"
    @remove="remove"
  >
    <template #content>
      <slot>
        <gl-collapsible-listbox
          :header-text="$options.i18n.headerText"
          :items="vulnerabilityStateGroups"
          :selected="selectedFilter"
          :disabled="disabled"
          @select="selectVulnerabilityStateGroup"
        />
        <div class="gl-flex gl-items-center gl-gap-2">
          <rule-multi-select
            :value="filters"
            :item-type-name="$options.i18n.vulnerabilityStates"
            :items="$options.APPROVAL_VULNERABILITY_STATES[selectedFilter]"
            data-testid="vulnerability-states-select"
            @input="emitVulnerabilityStates"
          />
          <gl-icon
            v-if="showPreviouslyExistingTooltip"
            :id="$options.POPOVER_TARGET_ID"
            name="information-o"
            data-testid="previously-existing-tooltip"
          />
        </div>
        <gl-popover
          v-if="showPreviouslyExistingTooltip"
          :target="$options.POPOVER_TARGET_ID"
          boundary="viewport"
          placement="top"
        >
          <gl-sprintf :message="$options.i18n.previouslyExistingTooltip">
            <template #bold="{ content }">
              <b>{{ content }}</b>
            </template>
          </gl-sprintf>
        </gl-popover>
      </slot>
    </template>
  </section-layout>
</template>
