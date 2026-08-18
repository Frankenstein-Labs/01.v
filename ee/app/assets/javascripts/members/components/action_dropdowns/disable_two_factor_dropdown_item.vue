<script>
import { GlDisclosureDropdownItem } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'DisableTwoFactorDropdownItem',
  components: { GlDisclosureDropdownItem },
  mixins: [glSlotsMixin],
  inject: ['namespace'],
  props: {
    modalMessage: {
      type: String,
      required: true,
    },
    userId: {
      type: Number,
      required: true,
    },
  },
  computed: {
    modalData() {
      return {
        message: this.modalMessage,
        userId: this.userId,
      };
    },
  },
  methods: {
    ...mapActions({
      showDisableTwoFactorModal(dispatch, payload) {
        return dispatch(`${this.namespace}/showDisableTwoFactorModal`, payload);
      },
    }),
  },
};
</script>

<template>
  <gl-disclosure-dropdown-item @action="showDisableTwoFactorModal(modalData)">
    <template v-if="glSlots().default" #list-item>
      <slot></slot>
    </template>
  </gl-disclosure-dropdown-item>
</template>
