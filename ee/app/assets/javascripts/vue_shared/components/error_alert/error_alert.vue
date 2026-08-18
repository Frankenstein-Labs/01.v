<script>
import { GlAlert } from '@gitlab/ui';
import { generateHelpTextWithLinks, mapSystemToFriendlyError } from '~/lib/utils/error_utils';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'ErrorAlert',
  components: { GlAlert },
  directives: {
    SafeHtml,
  },
  mixins: [glListenersMixin],
  props: {
    error: {
      type: [Error, String],
      required: false,
      default: null,
    },
    errorDictionary: {
      type: Object,
      required: false,
      default: () => {},
    },
    defaultError: {
      type: Object,
      required: false,
      default: () => {},
    },
    dismissible: {
      type: Boolean,
      required: false,
      default: false,
    },
    primaryButtonLink: {
      type: String,
      required: false,
      default: null,
    },
    primaryButtonText: {
      type: String,
      required: false,
      default: null,
    },
    secondaryButtonLink: {
      type: String,
      required: false,
      default: null,
    },
    secondaryButtonText: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    friendlyError() {
      return mapSystemToFriendlyError(this.error, this.errorDictionary, this.defaultError);
    },
    friendlyErrorMessage() {
      return generateHelpTextWithLinks(this.friendlyError);
    },
  },
};
</script>
<template>
  <gl-alert
    v-if="error"
    variant="danger"
    :title="friendlyError.title"
    :dismissible="dismissible"
    :primary-button-link="primaryButtonLink"
    :primary-button-text="primaryButtonText"
    :secondary-button-link="secondaryButtonLink"
    :secondary-button-text="secondaryButtonText"
    v-on="glListeners()"
  >
    <span v-safe-html="friendlyErrorMessage"></span>
  </gl-alert>
</template>
