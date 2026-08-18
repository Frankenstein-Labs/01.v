<script>
import { GlDisclosureDropdown, GlIcon } from '@gitlab/ui';
import { omit } from 'lodash-es';
import { s__, sprintf } from '~/locale';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import {
  FLOW_TRIGGER_MODE_EVENT,
  FLOW_TRIGGER_MODE_SCHEDULE,
} from 'ee/ai/duo_agents_platform/constants';
import {
  flowTriggerModeFor,
  getEnabledFlowTriggerTypes,
  toFlowTriggerTypeOption,
} from 'ee/ai/duo_agents_platform/utils';
import {
  eventConfigurationInvalidFeedback,
  isEventConfigurationValid,
} from './event_configurations/configurations';
import FlowTriggerConditionForm from './flow_trigger_condition_form.vue';
import FlowTriggerConditionRow from './flow_trigger_condition_row.vue';

export default {
  name: 'FlowTriggerConditions',
  components: {
    CrudComponent,
    FlowTriggerConditionForm,
    FlowTriggerConditionRow,
    GlDisclosureDropdown,
    GlIcon,
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
    showErrors: {
      type: Boolean,
      required: false,
      default: false,
    },
    itemTypeLabel: {
      type: String,
      required: true,
    },
  },
  emits: ['update:event-types', 'update:filter', 'update:filter-valid'],
  data() {
    return {
      // The condition currently open in the panel form, and where it belongs on save.
      // A null index means it is not in the list yet.
      draft: null,
      draftIndex: null,
    };
  },
  computed: {
    enabledTypes() {
      return getEnabledFlowTriggerTypes(this.glFeatures);
    },
    // An event type maps to a single filter scope, so it can only be configured once. The type
    // being edited stays selectable so reopening its form does not empty the picker.
    selectableEventTypes() {
      const editingType = this.draftIndex === null ? null : this.eventTypes[this.draftIndex];

      return this.enabledTypes
        .filter((type) => type.value !== FLOW_TRIGGER_MODE_SCHEDULE)
        .filter((type) => !this.eventTypes.includes(type.value) || type.value === editingType)
        .map((type) => toFlowTriggerTypeOption(type, this.itemTypeLabel, this.glFeatures));
    },
    // One schedule per trigger, because the whole schedule lives on a single filter scope.
    canAddSchedule() {
      return (
        this.enabledTypes.some((type) => type.value === FLOW_TRIGGER_MODE_SCHEDULE) &&
        !this.eventTypes.includes(FLOW_TRIGGER_MODE_SCHEDULE)
      );
    },
    canAddEvent() {
      return this.selectableEventTypes.length > 0;
    },
    addConditionItems() {
      const items = [];

      if (this.canAddSchedule) {
        items.push({
          text: s__('DuoAgentsPlatform|On a schedule'),
          description: s__('DuoAgentsPlatform|Run at a recurring time.'),
          icon: 'clock',
          action: () => this.startAdding(FLOW_TRIGGER_MODE_SCHEDULE),
        });
      }

      if (this.canAddEvent) {
        items.push({
          text: s__('DuoAgentsPlatform|On an event'),
          description: s__('DuoAgentsPlatform|Run when something happens in the project.'),
          icon: 'trigger-source',
          action: () => this.startAdding(FLOW_TRIGGER_MODE_EVENT),
        });
      }

      return items;
    },
    hasConditions() {
      return this.eventTypes.length > 0;
    },
    isEditing() {
      return this.draft !== null;
    },
    isAdding() {
      return this.isEditing && this.draftIndex === null;
    },
    isValid() {
      // An open form is work in progress. Committing it on the user's behalf could save a
      // half-configured condition, and ignoring it would drop something they believe they
      // added, so the trigger is not saveable until they finish or cancel it.
      return (
        !this.isEditing &&
        this.hasConditions &&
        this.eventTypes.every((typeValue) => isEventConfigurationValid(typeValue, this.filter))
      );
    },
    feedback() {
      if (!this.showErrors) {
        return null;
      }

      if (this.isEditing) {
        return s__('DuoAgentsPlatform|Finish or cancel the open condition before saving.');
      }

      if (!this.hasConditions) {
        return sprintf(
          s__('DuoAgentsPlatform|Add a condition so this %{itemType} knows when to run.'),
          { itemType: this.itemTypeLabel },
        );
      }

      return null;
    },
    // Rows draw their own dividers edge to edge, so they need a padding-free body. The empty
    // state is plain text and wants the panel's default padding back.
    bodyClass() {
      return this.hasConditions ? '!gl-p-0' : null;
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
    rowInvalidFeedback(typeValue) {
      return this.showErrors ? eventConfigurationInvalidFeedback(typeValue, this.filter) : null;
    },
    closeForm() {
      this.draft = null;
      this.draftIndex = null;
      this.$refs.crud.hideForm();
    },
    async openForm() {
      this.$refs.crud.showForm();
      // The row that opened the form is now disabled, so leaving focus on it would strand
      // keyboard users. Wait for the panel to render, then move focus into it.
      await this.$nextTick();
      this.$refs.form?.$el?.focus();
    },
    startAdding(mode) {
      this.draft = {
        mode,
        typeValue: mode === FLOW_TRIGGER_MODE_SCHEDULE ? FLOW_TRIGGER_MODE_SCHEDULE : null,
        filter: {},
      };
      this.draftIndex = null;
      this.openForm();
    },
    startEditing(index) {
      const typeValue = this.eventTypes[index];
      const scopedFilter = this.filter[typeValue];

      this.draft = {
        mode: flowTriggerModeFor(typeValue),
        typeValue,
        filter: scopedFilter === undefined ? {} : { [typeValue]: scopedFilter },
      };
      this.draftIndex = index;
      this.openForm();
    },
    saveDraft({ typeValue, filter }) {
      const previousType = this.isAdding ? null : this.eventTypes[this.draftIndex];

      const nextEventTypes = this.isAdding
        ? [...this.eventTypes, typeValue]
        : this.eventTypes.map((existing, index) =>
            index === this.draftIndex ? typeValue : existing,
          );

      // Dropping the previous scope first keeps a stale configuration from surviving an
      // edit that switched the condition to a different event type.
      this.$emit('update:event-types', nextEventTypes);
      this.$emit('update:filter', {
        ...omit(this.filter, previousType ? [previousType] : []),
        ...filter,
      });
      this.closeForm();
    },
    removeCondition(index) {
      // Removing the condition being edited would leave the form pointed at a stale index.
      if (this.draftIndex === index) {
        this.closeForm();
      } else if (this.draftIndex !== null && index < this.draftIndex) {
        this.draftIndex -= 1;
      }

      this.$emit(
        'update:event-types',
        this.eventTypes.filter((_, position) => position !== index),
      );
      this.$emit('update:filter', omit(this.filter, [this.eventTypes[index]]));
    },
  },
};
</script>

<template>
  <div>
    <crud-component
      ref="crud"
      :title="s__('DuoAgentsPlatform|Conditions')"
      :description="
        s__(
          'DuoAgentsPlatform|Run at set times, or when something happens in the project. Add as many as you need.',
        )
      "
      :count="eventTypes.length"
      show-zero-count
      :body-class="bodyClass"
    >
      <template v-if="addConditionItems.length" #actions>
        <gl-disclosure-dropdown
          :items="addConditionItems"
          :toggle-text="s__('DuoAgentsPlatform|Add condition')"
          size="small"
          placement="bottom-end"
        >
          <template #list-item="{ item }">
            <div class="gl-flex gl-items-start gl-gap-3">
              <gl-icon :name="item.icon" class="gl-mt-1 gl-shrink-0 gl-text-subtle" />
              <div class="gl-flex gl-flex-col">
                <strong>{{ item.text }}</strong>
                <span class="gl-text-sm gl-text-subtle">{{ item.description }}</span>
              </div>
            </div>
          </template>
        </gl-disclosure-dropdown>
      </template>

      <template #form>
        <flow-trigger-condition-form
          v-if="isEditing"
          ref="form"
          :key="draft.typeValue || draft.mode"
          :mode="draft.mode"
          :type-value="draft.typeValue"
          :filter="draft.filter"
          :type-options="selectableEventTypes"
          :is-new="isAdding"
          @save="saveDraft"
          @cancel="closeForm"
        />
      </template>

      <template v-if="!hasConditions" #empty>
        <span>{{ s__('DuoAgentsPlatform|No conditions yet. Add a schedule or an event.') }}</span>
      </template>

      <ul class="gl-mb-0 gl-list-none gl-p-0">
        <flow-trigger-condition-row
          v-for="(typeValue, index) in eventTypes"
          :key="typeValue"
          :type-value="typeValue"
          :filter="filter"
          :invalid-feedback="rowInvalidFeedback(typeValue)"
          :is-editing="draftIndex === index"
          @edit="startEditing(index)"
          @remove="removeCondition(index)"
        />
      </ul>
    </crud-component>

    <p
      v-if="feedback"
      role="alert"
      class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-danger"
      data-testid="conditions-error"
    >
      {{ feedback }}
    </p>
  </div>
</template>
