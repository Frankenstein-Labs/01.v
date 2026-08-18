<script>
import { uniqueId } from 'lodash-es';
import { logError } from '~/lib/logger';
import { initArkoseLabsChallenge, resetArkoseLabsChallenge } from '../init_arkose_labs';
import { CHALLENGE_CONTAINER_CLASS } from '../constants';

export default {
  name: 'PhoneVerificationArkoseApp',
  inject: {
    arkoseConfiguration: {
      default: null,
    },
    arkoseDataExchangePayload: {
      default: null,
    },
  },
  props: {
    resetSession: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['challenge-solved'],
  data() {
    return {
      arkoseLabsIframeShown: false,
      arkoseLabsContainerClass: uniqueId(CHALLENGE_CONTAINER_CLASS),
      arkoseObject: null,
      arkoseToken: '',
    };
  },
  watch: {
    arkoseToken(token) {
      this.$emit('challenge-solved', token);
    },
    resetSession: {
      immediate: true,
      handler(reset) {
        if (reset) {
          this.resetArkoseSession();
        }
      },
    },
  },
  async mounted() {
    try {
      this.arkoseObject = await initArkoseLabsChallenge({
        publicKey: this.arkoseConfiguration.apiKey,
        domain: this.arkoseConfiguration.domain,
        dataExchangePayload: this.arkoseDataExchangePayload,
        dataExchangePayloadPath: this.arkoseConfiguration.dataExchangePayloadPath,
        config: {
          selector: `.${this.arkoseLabsContainerClass}`,
          onShown: this.onArkoseLabsIframeShown,
          onCompleted: this.passArkoseLabsChallenge,
        },
      });
    } catch (error) {
      logError('ArkoseLabs initialization error', error);
    }
  },
  methods: {
    onArkoseLabsIframeShown() {
      this.arkoseLabsIframeShown = true;
    },
    passArkoseLabsChallenge(response) {
      this.arkoseToken = response.token;
    },
    resetArkoseSession() {
      resetArkoseLabsChallenge(this.arkoseObject);
    },
  },
};
</script>

<template>
  <div>
    <!-- We use a hidden input here to simulate 'user solved the challenge' and
    trigger `challenge-solved` event in feature tests. See
    https://gitlab.com/gitlab-org/gitlab/-/issues/459947 -->
    <input v-model="arkoseToken" type="hidden" data-testid="arkose-labs-token-input" />

    <div
      v-show="arkoseLabsIframeShown"
      class="arkose-labs-container gl-flex gl-justify-center"
      :class="arkoseLabsContainerClass"
      data-testid="arkose-labs-challenge"
    ></div>
  </div>
</template>
