<script>
import SessionExpireModal from '~/authentication/sessions/components/session_expire_modal.vue';
import { getExpiringSamlSession } from '../saml_sessions';

export default {
  name: 'SamlReloadModal',
  components: {
    SessionExpireModal,
  },
  props: {
    samlProviderId: {
      type: Number,
      required: true,
    },
    samlSessionsUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      sessionTimeout: null,
    };
  },
  async created() {
    const session = await getExpiringSamlSession({
      samlProviderId: this.samlProviderId,
      url: this.samlSessionsUrl,
    });

    if (session) {
      this.sessionTimeout = Date.now() + session.timeRemainingMs;
    }
  },
};
</script>

<template>
  <session-expire-modal
    v-if="sessionTimeout"
    :message="
      s__(
        'SAML|Please, reload the page and sign in again, if necessary. To avoid data loss, if you have unsaved edits, dismiss the modal and copy the unsaved text before refreshing the page.',
      )
    "
    :session-timeout="sessionTimeout"
    :title="s__('SAML|Your SAML session has expired')"
  />
</template>
