<script>
import { GlFormGroup, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'UserFilterFormGroup',
  components: { GlFormGroup, GlFormTextarea, GlSprintf, HelpPageLink },
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
    :label="s__('LDAP|User filter')"
    :state="state"
    :invalid-feedback="__('This field is required')"
  >
    <template #label-description>
      <gl-sprintf
        :message="s__('LDAP|View more information on %{linkStart}user filters%{linkEnd}.')"
      >
        <template #link="{ content }">
          <help-page-link href="administration/auth/ldap/_index" anchor="set-up-ldap-user-filter">{{
            content
          }}</help-page-link>
        </template>
      </gl-sprintf>
    </template>

    <gl-form-textarea
      :value="value"
      :rows="2"
      :no-resize="false"
      :state="state"
      :placeholder="s__('LDAP|Start typing')"
      :disabled="disabled"
      class="gl-max-w-48"
      @update="$emit('input', $event)"
    />
  </gl-form-group>
</template>
