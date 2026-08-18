<script>
import { GlAlert } from '@gitlab/ui';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';

const STORAGE_KEY = 'security_dashboard_no_longer_detected_vulnerabilities_alert_dismissed';

export default {
  name: 'NoLongerDetectedVulnerabilitiesAlert',
  components: {
    GlAlert,
    LocalStorageSync,
  },
  data() {
    return {
      isDismissed: false,
    };
  },
  computed: {
    isVisible() {
      return !this.isDismissed;
    },
  },
  methods: {
    dismiss() {
      this.isDismissed = true;
    },
  },
  i18n: {
    message: s__(
      'SecurityReports|In GitLab 19.2 and later, vulnerabilities that are no longer detected are excluded from vulnerability counts in the security dashboard.',
    ),
  },
  STORAGE_KEY,
};
</script>

<template>
  <local-storage-sync v-model="isDismissed" :storage-key="$options.STORAGE_KEY">
    <gl-alert
      v-if="isVisible"
      variant="info"
      class="gl-mb-5"
      data-testid="no-longer-detected-vulnerabilities-alert"
      @dismiss="dismiss"
    >
      {{ $options.i18n.message }}
    </gl-alert>
  </local-storage-sync>
</template>
