<script>
import CeSignupSubmitButton from '~/registrations/components/signup_submit_button.vue';
import { arkoseState } from 'ee/arkose_labs/state';

export default {
  name: 'SignupSubmitButtonEE',
  components: {
    CeSignupSubmitButton,
  },
  props: {
    ...CeSignupSubmitButton.props,
  },
  computed: {
    isLoading() {
      return arkoseState.awaitingToken;
    },
  },
};
</script>

<template>
  <ce-signup-submit-button
    :button-text="buttonText"
    :button-class="buttonClass"
    :track-label="trackLabel"
    :loading="isLoading"
  />
</template>
