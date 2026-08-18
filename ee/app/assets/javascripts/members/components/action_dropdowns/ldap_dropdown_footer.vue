<script>
import { GlButton, GlToastMixin } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { s__ } from '~/locale';

export default {
  name: 'LdapDropdownFooter',
  components: {
    GlButton,
  },
  mixins: [GlToastMixin],
  inject: ['namespace'],
  props: {
    memberId: {
      type: Number,
      required: true,
    },
  },
  methods: {
    ...mapActions({
      updateLdapOverride(dispatch, payload) {
        return dispatch(`${this.namespace}/updateLdapOverride`, payload);
      },
    }),
    handleClick() {
      this.updateLdapOverride({ memberId: this.memberId, override: false })
        .then(() => {
          this.$toast.show(s__('Members|Reverted to LDAP group sync settings.'));
        })
        .catch(() => {
          // Do nothing, error handled in `updateLdapOverride` Vuex action
        });
    },
  },
};
</script>

<template>
  <div class="gl-border-t gl-border-strong gl-p-2">
    <gl-button category="tertiary" class="gl-w-full" @click="handleClick">
      {{ s__('Members|Revert to LDAP synced settings') }}
    </gl-button>
  </div>
</template>
