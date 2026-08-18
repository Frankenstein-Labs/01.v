<script>
import { GlForm, GlLoadingIcon } from '@gitlab/ui';
import { logError } from '~/lib/logger';
import csrf from '~/lib/utils/csrf';
import { initArkoseLabsChallenge } from '../init_arkose_labs';
import { VERIFICATION_TOKEN_INPUT_NAME, CHALLENGE_CONTAINER_CLASS } from '../constants';

export default {
  name: 'IdentityVerificationArkoseApp',
  csrf,
  components: { GlForm, GlLoadingIcon },
  props: {
    publicKey: {
      type: String,
      required: true,
    },
    domain: {
      type: String,
      required: true,
    },
    sessionVerificationPath: {
      type: String,
      required: true,
    },
    dataExchangePayload: {
      type: String,
      required: false,
      default: undefined,
    },
    dataExchangePayloadPath: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  data() {
    return {
      arkoseLabsIframeShown: false,
      arkoseToken: '',
    };
  },
  async mounted() {
    try {
      await initArkoseLabsChallenge({
        publicKey: this.publicKey,
        domain: this.domain,
        dataExchangePayload: this.dataExchangePayload,
        dataExchangePayloadPath: this.dataExchangePayloadPath,
        config: {
          selector: `.${this.$options.CHALLENGE_CONTAINER_CLASS}`,
          onShown: this.onArkoseLabsIframeShown,
          onCompleted: this.submit,
        },
      });
    } catch (error) {
      logError('ArkoseLabs initialization error', error);
      this.submit();
    }
  },
  methods: {
    onArkoseLabsIframeShown() {
      this.arkoseLabsIframeShown = true;
    },
    submit({ token } = { token: '' }) {
      this.arkoseToken = token;

      this.$nextTick(() => {
        this.$refs.form.$el.submit();
      });
    },
  },
  VERIFICATION_TOKEN_INPUT_NAME,
  CHALLENGE_CONTAINER_CLASS,
};
</script>

<template>
  <gl-form
    ref="form"
    :action="sessionVerificationPath"
    method="post"
    data-testid="arkose-labs-token-form"
  >
    <input :value="$options.csrf.token" type="hidden" name="authenticity_token" />
    <input
      :name="$options.VERIFICATION_TOKEN_INPUT_NAME"
      type="hidden"
      :value="arkoseToken"
      data-testid="arkose-labs-token-input"
    />
    <div
      class="arkose-labs-container gl-flex gl-justify-center"
      :class="$options.CHALLENGE_CONTAINER_CLASS"
    >
      <gl-loading-icon v-if="!arkoseLabsIframeShown" size="lg" class="gl-my-4" />
    </div>
  </gl-form>
</template>
