<script>
import { GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';

export default {
  name: 'ServerFormGroup',
  components: { GlFormGroup, GlCollapsibleListbox },
  inject: ['ldapServers'],
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
};
</script>

<template>
  <gl-form-group
    :label="s__('LDAP|Server')"
    :state="state"
    :invalid-feedback="__('This field is required')"
  >
    <gl-collapsible-listbox
      :selected="value"
      :items="ldapServers"
      :toggle-text="value ? '' : s__('LDAP|Select server')"
      :variant="state ? 'default' : 'danger'"
      :disabled="disabled"
      class="gl-max-w-30"
      category="secondary"
      block
      @select="$emit('input', $event)"
    />
  </gl-form-group>
</template>
