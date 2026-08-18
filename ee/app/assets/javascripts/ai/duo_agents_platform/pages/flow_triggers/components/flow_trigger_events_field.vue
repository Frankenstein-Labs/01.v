<script>
import { GlCard, GlCollapsibleListbox } from '@gitlab/ui';
import { isEqual, uniqueId } from 'lodash-es';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { FLOW_TRIGGER_TYPES } from 'ee/ai/duo_agents_platform/constants';
import {
  getEnabledFlowTriggerTypes,
  toFlowTriggerTypeOption,
} from 'ee/ai/duo_agents_platform/utils';
import { getEventConfiguration } from './event_configurations/configurations';

const getConfigurableTypes = (values) =>
  values
    .map((value) => FLOW_TRIGGER_TYPES.find((type) => type.value === value))
    .filter((type) => type && getEventConfiguration(type.value));

export default {
  name: 'FlowTriggerEventsField',
  components: {
    GlCard,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    eventTypes: {
      type: Array,
      required: false,
      default: () => [],
    },
    filter: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    state: {
      type: Boolean,
      required: false,
      default: null,
    },
    showErrors: {
      type: Boolean,
      required: false,
      default: false,
    },
    listboxId: {
      type: String,
      required: false,
      default: () => uniqueId('flow-trigger-events-'),
    },
    itemTypeLabel: {
      type: String,
      required: true,
    },
  },
  emits: ['update:event-types', 'update:filter', 'update:filter-valid', 'blur'],
  computed: {
    eventTypeOptions() {
      return getEnabledFlowTriggerTypes(this.glFeatures).map((type) =>
        toFlowTriggerTypeOption(type, this.itemTypeLabel, this.glFeatures),
      );
    },
    configurableEventTypes() {
      const enabledValues = new Set(this.eventTypeOptions.map((option) => option.value));
      return getConfigurableTypes(this.eventTypes)
        .filter((type) => enabledValues.has(type.value))
        .map((type) => ({
          ...type,
          configuration: getEventConfiguration(type.value),
        }));
    },
    selectedEventTypeText() {
      if (!this.eventTypes.length) {
        return s__('DuoAgentsPlatform|Select one or multiple event types');
      }
      return this.eventTypeOptions
        .filter((option) => this.eventTypes.includes(option.value))
        .map((option) => option.text)
        .join(', ');
    },
    isValid() {
      return this.configurableEventTypes.every((type) => type.configuration.isValid(this.filter));
    },
    displayedInvalidFeedback() {
      if (!this.showErrors) return {};
      const feedback = {};
      this.configurableEventTypes.forEach((type) => {
        if (!type.configuration.isValid(this.filter)) {
          feedback[type.value] = type.configuration.invalidFeedback;
        }
      });
      return feedback;
    },
  },
  watch: {
    isValid: {
      immediate: true,
      handler(value) {
        this.$emit('update:filter-valid', value);
      },
    },
  },
  methods: {
    onSelectEventTypes(newValues) {
      const activeScopes = getConfigurableTypes(newValues).map((type) => type.value);
      const prunedFilter = Object.fromEntries(
        Object.entries(this.filter).filter(([scope]) => activeScopes.includes(scope)),
      );

      if (!isEqual(prunedFilter, this.filter)) {
        this.$emit('update:filter', prunedFilter);
      }
      this.$emit('update:event-types', newValues);
    },
    onUpdateFilter(newFilter) {
      this.$emit('update:filter', newFilter);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-5">
    <gl-collapsible-listbox
      :id="listboxId"
      :items="eventTypeOptions"
      :selected="eventTypes"
      :toggle-text="selectedEventTypeText"
      :header-text="s__('DuoAgentsPlatform|Select one or multiple event types')"
      multiple
      block
      fluid-width
      :state="state"
      @select="onSelectEventTypes"
      @blur="$emit('blur')"
    >
      <template #list-item="{ item }">
        <div class="gl-flex gl-flex-col">
          <strong>{{ item.text }}</strong>
          <span v-if="item.description" class="gl-text-sm gl-text-subtle">{{
            item.description
          }}</span>
        </div>
      </template>
    </gl-collapsible-listbox>

    <!-- Several configurations stack here, one per selected event type, so each is boxed and
         named. The single-condition form renders the same components without this chrome. -->
    <gl-card v-for="type in configurableEventTypes" :key="type.value">
      <template #header>
        <h4 class="gl-m-0 gl-text-base gl-font-semibold">{{ type.text }}</h4>
      </template>
      <component
        :is="type.configuration.component"
        v-bind="type.configuration.props"
        :value="filter"
        :invalid-feedback="displayedInvalidFeedback[type.value] || null"
        @input="onUpdateFilter"
      />
    </gl-card>
  </div>
</template>
