<script>
import { GlFormGroup, GlFormRadioGroup } from '@gitlab/ui';
import { s__ } from '~/locale';

export const GROUP_CN = 'group_cn';
export const USER_FILTER = 'user_filter';

const SYNC_METHODS = [
  { value: GROUP_CN, text: s__('LDAP|Group cn') },
  { value: USER_FILTER, text: s__('LDAP|User filter') },
];

export default {
  name: 'SyncMethodFormGroup',
  components: { GlFormGroup, GlFormRadioGroup },
  props: {
    value: {
      type: String,
      required: false,
      default: null,
    },
    state: {
      type: Boolean,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['input'],
  SYNC_METHODS,
};
</script>

<template>
  <gl-form-group
    :label="s__('LDAP|Sync method')"
    :state="state"
    :invalid-feedback="__('This field is required')"
  >
    <gl-form-radio-group
      :checked="value"
      :state="state ? null : false"
      :options="$options.SYNC_METHODS"
      :disabled="disabled"
      @input="$emit('input', $event)"
    />
  </gl-form-group>
</template>
