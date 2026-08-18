<script>
import { GlButton } from '@gitlab/ui';
import Tracking from '~/tracking';
import {
  PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
  PQL_PRODUCT_INTERACTION,
  PQL_BUTTON_TEXT,
} from '../constants';
import eventHub from '../event_hub';

export default {
  name: 'HandRaiseLeadButton',
  components: {
    GlButton,
  },
  mixins: [Tracking.mixin()],
  props: {
    ctaTracking: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    buttonText: {
      type: String,
      required: false,
      default: PQL_BUTTON_TEXT,
    },
    buttonAttributes: {
      type: Object,
      required: true,
    },
    glmContent: {
      type: String,
      required: true,
    },
    productInteraction: {
      type: String,
      required: false,
      default: PQL_PRODUCT_INTERACTION,
    },
  },
  computed: {
    // eslint-disable-next-line vue/no-unused-properties -- used by Tracking mixin for analytics tracking
    tracking() {
      return {
        label: PQL_HAND_RAISE_MODAL_TRACKING_LABEL,
        experiment: this.ctaTracking.experiment,
      };
    },
  },
  methods: {
    openModal() {
      this.trackBtnClick();

      eventHub.$emit('openModal', {
        productInteraction: this.productInteraction,
        ctaTracking: this.ctaTracking,
        glmContent: this.glmContent,
      });
    },
    trackBtnClick() {
      const { action, ...options } = this.ctaTracking;
      if (action) {
        this.track(action, options);
      }
    },
  },
};
</script>

<template>
  <gl-button v-bind="buttonAttributes" @click="openModal">
    {{ buttonText }}
  </gl-button>
</template>
