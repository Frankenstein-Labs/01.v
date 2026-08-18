<script>
import { uniqueId } from 'lodash-es';
import { logError } from '~/lib/logger';
import { createAlert } from '~/alert';
import DomElementListener from '~/vue_shared/components/dom_element_listener.vue';
import { scrollUp } from '~/lib/utils/scroll_utils';
import { initArkoseLabsChallenge } from '../init_arkose_labs';
import { arkoseState, resetArkoseState } from '../state';
import {
  VERIFICATION_LOADING_MESSAGE,
  VERIFICATION_REQUIRED_MESSAGE,
  VERIFICATION_TOKEN_INPUT_NAME,
  CHALLENGE_CONTAINER_CLASS,
  ARKOSE_TOKEN_WAIT_TIMEOUT_MS,
} from '../constants';

export default {
  name: 'SignUpArkoseApp',
  components: {
    DomElementListener,
  },
  props: {
    formSelector: {
      type: String,
      required: true,
    },
    publicKey: {
      type: String,
      required: true,
    },
    domain: {
      type: String,
      required: true,
    },
    dataExchangePayload: {
      type: String,
      required: false,
      default: undefined,
    },
  },
  data() {
    return {
      arkoseLabsIframeShown: false,
      arkoseLabsContainerClass: uniqueId(CHALLENGE_CONTAINER_CLASS),
      arkoseToken: '',
      errorAlert: null,
      arkoseChallengeBypassed: false,
    };
  },
  computed: {
    challengeResolved() {
      return Boolean(this.arkoseToken) || this.arkoseChallengeBypassed;
    },
  },
  watch: {
    challengeResolved(resolved) {
      if (resolved && this.pendingFormSubmit) {
        this.submitPendingForm();
      }
    },
  },
  created() {
    this.pendingFormSubmit = null;
    this.pendingSubmitTimeout = null;
  },
  async mounted() {
    resetArkoseState();

    try {
      await initArkoseLabsChallenge({
        publicKey: this.publicKey,
        domain: this.domain,
        dataExchangePayload: this.dataExchangePayload,
        config: {
          selector: `.${this.arkoseLabsContainerClass}`,
          onShown: this.onArkoseLabsIframeShown,
          onCompleted: this.passArkoseLabsChallenge,
          onError: this.bypassArkoseOnFailure,
        },
      });
    } catch (error) {
      this.bypassArkoseOnFailure(error);
    }
  },
  beforeDestroy() {
    clearTimeout(this.pendingSubmitTimeout);
  },
  methods: {
    submitPendingForm() {
      clearTimeout(this.pendingSubmitTimeout);
      this.pendingSubmitTimeout = null;
      const form = this.pendingFormSubmit;
      this.pendingFormSubmit = null;
      this.$nextTick(() => {
        form.submit();
      });
    },
    deferSubmitUntilToken(form) {
      clearTimeout(this.pendingSubmitTimeout);
      arkoseState.awaitingToken = true;
      this.pendingFormSubmit = form;
      this.pendingSubmitTimeout = setTimeout(() => {
        this.pendingFormSubmit = null;
        this.pendingSubmitTimeout = null;
        arkoseState.awaitingToken = false;
        this.showVerificationError();
      }, ARKOSE_TOKEN_WAIT_TIMEOUT_MS);
    },
    showLoadingError() {
      this.errorAlert = createAlert({ message: VERIFICATION_LOADING_MESSAGE });
      scrollUp(this.$el);
    },
    showVerificationError() {
      this.errorAlert = createAlert({ message: VERIFICATION_REQUIRED_MESSAGE });
      scrollUp(this.$el);
    },
    onArkoseLabsIframeShown() {
      this.arkoseLabsIframeShown = true;
      arkoseState.iframeShown = true;
    },
    passArkoseLabsChallenge(response) {
      this.arkoseToken = response.token;
      arkoseState.token = response.token;
    },
    bypassArkoseOnFailure(error) {
      logError('ArkoseLabs initialization error', error);

      this.arkoseChallengeBypassed = true;
      arkoseState.challengeBypassed = true;
    },
    onSubmit(e) {
      this.errorAlert?.dismiss();

      if (this.arkoseChallengeBypassed || this.arkoseToken) {
        return;
      }

      e.preventDefault();
      e.stopPropagation();

      if (this.arkoseLabsIframeShown) {
        this.deferSubmitUntilToken(e.target);
      } else {
        this.showLoadingError();
      }
    },
  },
  VERIFICATION_TOKEN_INPUT_NAME,
};
</script>

<template>
  <div>
    <dom-element-listener :selector="formSelector" @submit="onSubmit" />
    <input
      v-model="arkoseToken"
      :name="$options.VERIFICATION_TOKEN_INPUT_NAME"
      type="hidden"
      data-testid="arkose-labs-token-input"
    />
    <div
      v-show="arkoseLabsIframeShown"
      class="arkose-labs-container gl-flex gl-justify-center"
      :class="arkoseLabsContainerClass"
      data-testid="arkose-labs-challenge"
    ></div>
  </div>
</template>
