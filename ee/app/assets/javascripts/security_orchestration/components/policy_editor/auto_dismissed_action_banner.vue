<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { __, s__ } from '~/locale';
import { AUTO_DISMISSED_ACTION_STORAGE_KEY } from './constants';

export default {
  BANNER_STORAGE_KEY: AUTO_DISMISSED_ACTION_STORAGE_KEY,
  i18n: {
    bannerContent: s__(
      'SecurityOrchestration|%{boldStart}Experimental feature:%{boldEnd} Try out auto-dismissed actions for vulnerability policy. This feature is expected to be fully available in %{boldStart}18.8.%{boldEnd}',
    ),
    secondaryButtonText: __("Don't show again"),
    title: __('Experimental'),
    label: __('Auto-dismiss action'),
  },
  name: 'AutoDismissedActionBanner',
  components: {
    LocalStorageSync,
    GlAlert,
    GlSprintf,
  },
  data() {
    return {
      alertDismissed: false,
    };
  },
  methods: {
    dismissBanner() {
      this.alertDismissed = true;
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="alertDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <!-- eslint-disable vue/v-on-event-hyphenation -->
    <gl-alert
      v-if="!alertDismissed"
      :secondary-button-text="$options.i18n.secondaryButtonText"
      variant="tip"
      @dismiss="dismissBanner"
      @secondaryAction="dismissBanner"
    >
      <!-- eslint-enable vue/v-on-event-hyphenation -->
      <gl-sprintf :message="$options.i18n.bannerContent">
        <template #bold="{ content }">
          <strong>{{ content }}</strong>
        </template>
      </gl-sprintf>
    </gl-alert>
  </local-storage-sync>
</template>
