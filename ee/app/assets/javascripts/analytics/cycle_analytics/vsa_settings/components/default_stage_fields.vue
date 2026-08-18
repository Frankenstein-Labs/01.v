<script>
import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { i18n, ADDITIONAL_DEFAULT_STAGE_EVENTS } from '../constants';
import StageFieldMove from './stage_field_move.vue';
import StageFieldActions from './stage_field_actions.vue';

const findStageEvent = (stageEvents = [], eid = null) => {
  if (!eid) return '';
  return stageEvents.find(({ identifier }) => identifier === eid);
};

const eventIdToName = (stageEvents = [], eid) => {
  const event = findStageEvent(stageEvents, eid);
  return event?.name || '';
};

export default {
  name: 'DefaultStageFields',
  components: {
    StageFieldMove,
    StageFieldActions,
    GlFormGroup,
    GlFormInput,
  },
  inject: ['stageEvents'],
  props: {
    index: {
      type: Number,
      required: true,
    },
    stageLabel: {
      type: String,
      required: true,
    },
    totalStages: {
      type: Number,
      required: true,
    },
    stage: {
      type: Object,
      required: true,
    },
    errors: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['move', 'hide'],
  methods: {
    isValid(field) {
      return !this.errors[field] || !this.errors[field]?.length;
    },
    renderError(field) {
      return this.errors[field] ? this.errors[field]?.join('\n') : null;
    },
    eventName(eventId) {
      return eventIdToName([...this.stageEvents, ...ADDITIONAL_DEFAULT_STAGE_EVENTS], eventId);
    },
  },
  i18n,
};
</script>
<template>
  <div class="gl-mb-4" data-testid="value-stream-stage-fields">
    <div class="gl-flex gl-gap-5">
      <stage-field-move :index="index" :stage-count="totalStages" @move="$emit('move', $event)" />

      <div class="gl-grow">
        <gl-form-group
          :state="isValid('name')"
          :invalid-feedback="renderError('name')"
          :data-testid="`default-stage-name-${index}`"
        >
          <template #label>
            <span class="gl-heading-3">{{ stageLabel }}: {{ stage.name }}</span>
          </template>
          <!-- eslint-disable vue/no-mutating-props -->
          <gl-form-input
            v-model.trim="stage.name"
            :name="`create-value-stream-stage-${index}`"
            :placeholder="$options.i18n.FORM_FIELD_STAGE_NAME_PLACEHOLDER"
            disabled="disabled"
            required
          />
          <!-- eslint-enable vue/no-mutating-props -->
        </gl-form-group>

        <div class="gl-flex gl-flex-col gl-gap-2">
          <div class="gl-flex gl-flex-wrap gl-gap-2" :data-testid="`stage-start-event-${index}`">
            <span class="gl-shrink-0 gl-font-bold">{{
              $options.i18n.DEFAULT_FIELD_START_EVENT_LABEL
            }}</span>
            <span>{{ eventName(stage.startEventIdentifier) }}</span>
          </div>
          <div class="gl-flex gl-flex-wrap gl-gap-2" :data-testid="`stage-end-event-${index}`">
            <span class="gl-shrink-0 gl-font-bold">{{
              $options.i18n.DEFAULT_FIELD_END_EVENT_LABEL
            }}</span>
            <span>{{ eventName(stage.endEventIdentifier) }}</span>
          </div>
        </div>
      </div>

      <stage-field-actions
        class="gl-mt-3 @sm/panel:!gl-mt-7"
        :index="index"
        @hide="$emit('hide', $event)"
      />
    </div>
  </div>
</template>
