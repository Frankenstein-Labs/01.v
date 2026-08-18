<script>
import { GlCollapse, GlButton } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { __ } from '~/locale';

export default {
  name: 'GeoListItemErrors',
  i18n: {
    showErrors: __('Expand errors'),
    hideErrors: __('Collapse errors'),
  },
  components: {
    GlCollapse,
    GlButton,
    HelpPageLink,
  },
  props: {
    errorsArray: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isVisible: false,
    };
  },
  computed: {
    toggleButtonText() {
      return this.isVisible ? this.$options.i18n.hideErrors : this.$options.i18n.showErrors;
    },
    chevron() {
      return this.isVisible ? 'chevron-down' : 'chevron-right';
    },
  },
  methods: {
    toggleErrorVisibility() {
      this.isVisible = !this.isVisible;
    },
  },
};
</script>

<template>
  <section class="gl-mt-3">
    <gl-button
      variant="link"
      size="small"
      class="gl-p-0"
      :icon="chevron"
      @click="toggleErrorVisibility"
    >
      {{ toggleButtonText }}
    </gl-button>
    <gl-collapse :visible="isVisible">
      <div class="gl-border gl-mt-2 gl-rounded-base gl-bg-subtle gl-px-4 gl-py-3">
        <div
          v-for="(error, index) in errorsArray"
          :key="index"
          class="gl-mb-2 last:gl-mb-0"
          data-testid="geo-list-error-item"
        >
          <p class="gl-mb-0 gl-text-sm">
            <span>{{ error.label }}:</span>
            <span class="gl-ml-1">{{ error.message }}</span>
          </p>
        </div>
        <help-page-link
          class="gl-text-sm"
          href="administration/geo/replication/troubleshooting/synchronization_verification"
          target="_blank"
          >{{ s__('Geo|View troubleshooting docs') }}</help-page-link
        >
      </div>
    </gl-collapse>
  </section>
</template>
