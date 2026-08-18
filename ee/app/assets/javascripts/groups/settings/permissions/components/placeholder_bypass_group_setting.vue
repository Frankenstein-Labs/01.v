<script>
import { GlDatepicker, GlFormGroup, GlFormCheckbox } from '@gitlab/ui';

export default {
  name: 'PlaceholderBypassGroupSetting',
  components: {
    GlDatepicker,
    GlFormGroup,
    GlFormCheckbox,
  },
  props: {
    maxDate: {
      type: Date,
      required: true,
    },
    minDate: {
      type: Date,
      required: true,
    },
    isBypassOn: {
      type: Boolean,
      required: true,
    },
    currentExpiryDate: {
      type: String,
      required: false,
      default: '',
    },
    shouldDisableCheckbox: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    /** On form load, if there's a saved date, use it if it hasn't passed.
     * Otherwise, if bypass was previously enabled but no date, * set one. If neither case applies, no initial date.
     * */
    let initialDate = null;
    let initialBypassState = this.isBypassOn;

    if (this.currentExpiryDate) {
      const dateObject = new Date(this.currentExpiryDate);
      const now = new Date();

      if (dateObject <= now) {
        initialBypassState = false;
      } else {
        initialDate = dateObject;
      }
    } else if (this.isBypassOn) {
      initialDate = this.minDate;
    }

    return {
      selectedDate: initialDate,
      bypassIsOn: initialBypassState,
    };
  },
  watch: {
    bypassIsOn(newValue) {
      if (!newValue) {
        this.selectedDate = null;
      } else if (!this.selectedDate) {
        this.selectedDate = this.minDate;
      }
    },
  },
};
</script>

<template>
  <div>
    <gl-form-checkbox
      id="group[allow_enterprise_bypass_placeholder_confirmation]"
      v-model="bypassIsOn"
      class="gl-mt-2"
      data-testid="placeholder-bypass-checkbox"
      :disabled="shouldDisableCheckbox"
      input-name="group[allow_enterprise_bypass_placeholder_confirmation]"
    >
      {{ s__('UserMapping|Reassign placeholders to enterprise users without user confirmation') }}
    </gl-form-checkbox>

    <input
      type="hidden"
      data-testid="hidden-bypass-checkbox"
      name="group[allow_enterprise_bypass_placeholder_confirmation]"
      :value="bypassIsOn ? '1' : '0'"
    />

    <gl-form-group
      v-if="!shouldDisableCheckbox"
      class="gl-mt-4"
      :label="s__('UserMapping|When to restore user confirmation')"
    >
      <gl-datepicker
        id="group[enterprise_bypass_expires_at]"
        v-model="selectedDate"
        :min-date="minDate"
        :max-date="maxDate"
        :disabled="!bypassIsOn"
        show-clear-button
        data-testid="placeholder-bypass-expiry-date-field"
      />
      <!-- when bypass is turned off and datepicker is disabled, the date still needs to be cleared on the backend -->
      <input
        type="hidden"
        name="group[enterprise_bypass_expires_at]"
        data-testid="placeholder-bypass-hidden-expiry-date"
        :value="selectedDate ? selectedDate : ''"
      />
    </gl-form-group>
  </div>
</template>
