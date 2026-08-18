<script>
import { GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';

const DEFAULT_TITLE = s__(
  'IdentityVerification|Before you can run pipelines, we need to verify your account.',
);

export default {
  name: 'PipelineAccountVerificationAlert',
  components: { GlAlert },
  i18n: {
    title: DEFAULT_TITLE,
    description: s__(
      `IdentityVerification|We won't ask you for this information again. It will never be used for marketing purposes.`,
    ),
    buttonText: s__('IdentityVerification|Verify my account'),
  },
  inject: ['identityVerificationRequired', 'identityVerificationPath'],
  props: {
    title: {
      type: String,
      required: false,
      default: DEFAULT_TITLE,
    },
    dismissible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      isVisible: true,
    };
  },
  methods: {
    dismissAlert() {
      this.isVisible = false;
    },
  },
};
</script>

<template>
  <gl-alert
    v-if="identityVerificationRequired && isVisible"
    :title="title"
    :primary-button-text="$options.i18n.buttonText"
    :primary-button-link="identityVerificationPath"
    :dismissible="dismissible"
    variant="danger"
    @dismiss="dismissAlert"
  >
    {{ $options.i18n.description }}
  </gl-alert>
</template>
