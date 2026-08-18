<script>
import { GlFormRadioGroup, GlFormInput, GlFormGroup } from '@gitlab/ui';
import { s__, n__ } from '~/locale';

const EXPIRATION_COLUMNS = [
  {
    text: s__('AiPowered|After the conversation was last updated'),
    value: 'last_updated_at',
  },
  {
    text: s__('AiPowered|After the conversation was created'),
    value: 'created_at',
  },
];

export default {
  name: 'DuoChatHistoryExpirationForm',
  i18n: {
    sectionTitle: s__('AiPowered|GitLab Duo Chat conversations'),
    subtitleText: s__('AiPowered|Chat conversations expire:'),
  },
  components: {
    GlFormRadioGroup,
    GlFormInput,
    GlFormGroup,
  },
  inject: ['duoChatExpirationDays', 'duoChatExpirationColumn'],
  emits: ['change-expiration-column', 'change-expiration-days'],
  data() {
    return {
      expirationDays: this.duoChatExpirationDays,
      expirationColumn: this.duoChatExpirationColumn,
    };
  },
  computed: {
    daysText() {
      return n__('day', 'days', this.expirationDays);
    },
  },
  methods: {
    daysChanged(value) {
      this.$emit('change-expiration-days', parseInt(value, 10));
    },
    columnChanged(value) {
      this.$emit('change-expiration-column', value);
    },
  },
  EXPIRATION_COLUMNS,
};
</script>
<template>
  <div>
    <gl-form-group
      :label-description="$options.i18n.subtitleText"
      :label="$options.i18n.sectionTitle"
      label-for="history-expiration-days"
      class="gl-my-4"
    >
      <div class="gl-flex gl-items-center">
        <gl-form-input
          id="history-expiration-days"
          v-model="expirationDays"
          width="xs"
          type="number"
          min="1"
          max="30"
          @change="daysChanged"
        />
        <span class="gl-ml-3">
          {{ daysText }}
        </span>
      </div>
    </gl-form-group>
    <gl-form-radio-group
      id="history-expiration-criteria"
      v-model="expirationColumn"
      :options="$options.EXPIRATION_COLUMNS"
      name="history_expiration_on[category]"
      required
      @change="columnChanged"
    />
  </div>
</template>
