import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { scrollToElement } from '~/lib/utils/scroll_utils';

export default {
  data() {
    return {
      actionErrorMessage: '',
    };
  },
  computed: {
    hasActionError() {
      return Boolean(this.actionErrorMessage.length);
    },
  },
  methods: {
    handleActionError(message, exception = null) {
      this.actionErrorMessage = message;
      this.scrollToTop();
      if (exception !== null) {
        Sentry.captureException(exception);
      }
    },
    resetActionError() {
      this.actionErrorMessage = '';
    },
    scrollToTop() {
      scrollToElement(this.$el);
    },
  },
};
