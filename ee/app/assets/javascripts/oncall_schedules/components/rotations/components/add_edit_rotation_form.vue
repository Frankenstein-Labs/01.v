<script>
import {
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlDatepicker,
  GlTokenSelector,
  GlAvatar,
  GlAvatarLabeled,
  GlToggle,
  GlCard,
  GlCollapsibleListbox,
} from '@gitlab/ui';
import { range } from 'lodash-es';
import {
  LENGTH_ENUM,
  HOURS_IN_DAY,
  CHEVRON_SKIPPING_SHADE_ENUM,
  CHEVRON_SKIPPING_PALETTE_ENUM,
} from 'ee/oncall_schedules/constants';
import { format24HourTimeStringFromInt } from '~/lib/utils/datetime_utility';
import { formatParticipantsForTokenSelector } from 'ee/oncall_schedules/utils/common_utils';
import { s__, __ } from '~/locale';

export const i18n = {
  selectParticipant: s__('OnCallSchedules|Select participant'),
  errorMsg: s__('OnCallSchedules|Failed to add rotation'),
  fields: {
    name: { title: __('Name'), error: s__('OnCallSchedules|Rotation name cannot be empty') },
    participants: {
      title: __('Participants'),
      error: s__('OnCallSchedules|Rotation participants cannot be empty'),
    },
    rotationLength: {
      title: s__('OnCallSchedules|Rotation length'),
      error: s__('OnCallSchedules|Rotation length must be a positive number'),
      description: s__(
        'OnCallSchedules|Please note, rotations with shifts that are less than four hours are currently not supported in the weekly view.',
      ),
    },
    startsAt: {
      title: __('Starts on'),
      error: s__('OnCallSchedules|Rotation start date cannot be empty'),
    },
    endsAt: {
      enableToggle: s__('OnCallSchedules|Enable end date'),
      title: __('Ends on'),
      error: s__('OnCallSchedules|Rotation end date/time must come after start date/time'),
    },
    restrictToTime: {
      enableToggle: s__('OnCallSchedules|Restrict to time intervals'),
      title: s__('OnCallSchedules|For this rotation, on-call will be:'),
    },
  },
};

export default {
  name: 'AddEditRotationForm',
  i18n,
  HOURS_IN_DAY,
  tokenColorPalette: {
    shade: CHEVRON_SKIPPING_SHADE_ENUM,
    palette: CHEVRON_SKIPPING_PALETTE_ENUM,
  },
  LENGTH_ENUM,
  components: {
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlDatepicker,
    GlTokenSelector,
    GlAvatar,
    GlAvatarLabeled,
    GlToggle,
    GlCard,
    GlCollapsibleListbox,
  },
  props: {
    form: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    validationState: {
      type: Object,
      required: true,
    },
    participants: {
      type: Array,
      required: true,
    },
    schedule: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['filter-participants', 'update-rotation-form'],
  computed: {
    formParticipantsWithTokenStyles() {
      return formatParticipantsForTokenSelector(this.form.participants);
    },
    timeOptions() {
      return range(HOURS_IN_DAY).map((hour) => {
        return {
          value: hour,
          text: format24HourTimeStringFromInt(hour),
        };
      });
    },
    rotationLengthUnitsItems() {
      return Object.entries(LENGTH_ENUM || {}).map(([text, value]) => ({
        value,
        text,
      }));
    },
    rotationLengthUnitsToggleText() {
      return this.rotationLengthUnitsItems.find(
        ({ value }) => value === this.form.rotationLength.unit,
      )?.text;
    },
  },
  methods: {
    format24HourTimeStringFromInt,
    handleUnitSelectRotationUnit(selectedUnit) {
      this.$emit('update-rotation-form', {
        type: 'rotationLength.unit',
        value: selectedUnit,
      });
    },
    handleTimeSelect(selectedTime, type) {
      this.$emit('update-rotation-form', {
        type,
        value: selectedTime,
      });
    },
  },
};
</script>

<template>
  <gl-form>
    <div class="gl-w-full @sm/panel:gl-w-3/4">
      <gl-form-group
        :label="$options.i18n.fields.name.title"
        label-size="sm"
        label-for="rotation-name"
        :invalid-feedback="$options.i18n.fields.name.error"
        :state="validationState.name"
      >
        <gl-form-input
          id="rotation-name"
          data-testid="rotation-name-field"
          :value="form.name"
          @change="$emit('update-rotation-form', { type: 'name', value: $event })"
        />
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.fields.participants.title"
        label-size="sm"
        label-for="rotation-participants"
        :invalid-feedback="$options.i18n.fields.participants.error"
        :state="validationState.participants"
      >
        <gl-token-selector
          :selected-tokens="formParticipantsWithTokenStyles"
          :dropdown-items="participants"
          :loading="isLoading"
          @text-input="$emit('filter-participants', $event)"
          @blur="$emit('update-rotation-form', { type: 'participants', value: form.participants })"
          @input="$emit('update-rotation-form', { type: 'participants', value: $event })"
        >
          <template #token-content="{ token }">
            <gl-avatar v-if="token.avatarUrl" :src="token.avatarUrl" :size="16" />
            {{ token.name }}
          </template>
          <template #dropdown-item-content="{ dropdownItem }">
            <gl-avatar-labeled
              :src="dropdownItem.avatarUrl"
              :size="32"
              :label="dropdownItem.name"
              :sub-label="dropdownItem.username"
            />
          </template>
        </gl-token-selector>
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.fields.rotationLength.title"
        :description="$options.i18n.fields.rotationLength.description"
        label-size="sm"
        label-for="rotation-length"
        :invalid-feedback="$options.i18n.fields.rotationLength.error"
        :state="validationState.rotationLength"
      >
        <div class="gl-flex">
          <gl-form-input
            id="rotation-length"
            type="number"
            class="gl-mr-3 gl-w-12"
            min="1"
            :value="form.rotationLength.length"
            @input="$emit('update-rotation-form', { type: 'rotationLength.length', value: $event })"
          />
          <gl-collapsible-listbox
            :toggle-text="rotationLengthUnitsToggleText"
            :selected="form.rotationLength.unit"
            :items="rotationLengthUnitsItems"
            @select="handleUnitSelectRotationUnit"
          />
        </div>
      </gl-form-group>

      <gl-form-group
        :label="$options.i18n.fields.startsAt.title"
        label-size="sm"
        :invalid-feedback="$options.i18n.fields.startsAt.error"
        :state="validationState.startsAt"
      >
        <div class="gl-flex gl-items-center">
          <gl-datepicker
            class="gl-mr-3"
            :value="form.startsAt.date"
            @input="$emit('update-rotation-form', { type: 'startsAt.date', value: $event })"
          >
            <template #default="{ formattedDate }">
              <gl-form-input
                class="gl-w-full"
                data-testid="state-date-field"
                :value="formattedDate"
                :placeholder="__(`YYYY-MM-DD`)"
              />
            </template>
          </gl-datepicker>
          <span> {{ __('at') }} </span>

          <gl-collapsible-listbox
            data-testid="rotation-start-time"
            class="gl-px-3"
            :text="format24HourTimeStringFromInt(form.startsAt.time)"
            :toggle-text="format24HourTimeStringFromInt(form.startsAt.time)"
            :selected="form.startsAt.time"
            :items="timeOptions"
            @select="handleTimeSelect($event, 'startsAt.time')"
          />
          <span> {{ schedule.timezone }} </span>
        </div>
      </gl-form-group>
    </div>
    <div class="gl-inline-block">
      <gl-toggle
        :value="form.isEndDateEnabled"
        :label="$options.i18n.fields.endsAt.enableToggle"
        label-position="left"
        class="gl-mb-5"
        @change="
          $emit('update-rotation-form', { type: 'isEndDateEnabled', value: !form.isEndDateEnabled })
        "
      />

      <gl-card v-if="form.isEndDateEnabled" data-testid="rotation-ends-on">
        <gl-form-group
          :label="$options.i18n.fields.endsAt.title"
          label-size="sm"
          :state="validationState.endsAt"
          :invalid-feedback="$options.i18n.fields.endsAt.error"
          class="gl-mb-0"
        >
          <div class="gl-flex gl-items-center">
            <gl-datepicker
              class="gl-mr-3"
              :value="form.endsAt.date"
              @input="$emit('update-rotation-form', { type: 'endsAt.date', value: $event })"
            >
              <template #default="{ formattedDate }">
                <gl-form-input
                  class="gl-w-full"
                  :value="formattedDate"
                  :placeholder="__(`YYYY-MM-DD`)"
                />
              </template>
            </gl-datepicker>
            <span> {{ __('at') }} </span>
            <gl-collapsible-listbox
              data-testid="rotation-end-time"
              class="gl-px-3"
              :toggle-text="format24HourTimeStringFromInt(form.endsAt.time)"
              :selected="form.endsAt.time"
              :items="timeOptions"
              @select="handleTimeSelect($event, 'endsAt.time')"
            />
            <span>{{ schedule.timezone }}</span>
          </div>
        </gl-form-group>
      </gl-card>

      <gl-toggle
        :value="form.isRestrictedToTime"
        data-testid="restricted-to-toggle"
        :label="$options.i18n.fields.restrictToTime.enableToggle"
        label-position="left"
        class="gl-mt-5"
        @change="
          $emit('update-rotation-form', {
            type: 'isRestrictedToTime',
            value: !form.isRestrictedToTime,
          })
        "
      />

      <gl-card v-if="form.isRestrictedToTime" data-testid="restricted-to-time" class="gl-mt-5">
        <gl-form-group
          :label="$options.i18n.fields.restrictToTime.title"
          label-size="sm"
          :invalid-feedback="$options.i18n.fields.endsAt.error"
          class="gl-mb-0"
        >
          <div class="gl-flex gl-items-center">
            <span> {{ __('From') }} </span>
            <gl-collapsible-listbox
              data-testid="restricted-from"
              :text="format24HourTimeStringFromInt(form.restrictedTo.startTime)"
              class="gl-px-3"
              :toggle-text="format24HourTimeStringFromInt(form.restrictedTo.startTime)"
              :items="timeOptions"
              :selected="form.restrictedTo.startTime"
              @select="handleTimeSelect($event, 'restrictedTo.startTime')"
            />

            <span> {{ __('To') }} </span>
            <gl-collapsible-listbox
              data-testid="restricted-to"
              :text="format24HourTimeStringFromInt(form.restrictedTo.endTime)"
              :toggle-text="format24HourTimeStringFromInt(form.restrictedTo.endTime)"
              class="gl-px-3"
              :items="timeOptions"
              :selected="form.restrictedTo.endTime"
              @select="handleTimeSelect($event, 'restrictedTo.endTime')"
            />
            <span>{{ schedule.timezone }} </span>
          </div>
        </gl-form-group>
      </gl-card>
    </div>
  </gl-form>
</template>
