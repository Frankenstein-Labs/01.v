<script>
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';

export default {
  SCAN_EXECUTION_ACTION_LIMIT_PATH: helpPagePath(
    'user/application_security/policies/scan_execution_policies',
  ),
  BANNER_STORAGE_KEY: 'security_policies_exceeding_scheduled_rules',
  i18n: {
    bannerTitle: s__(
      'SecurityOrchestration|Maximum security policy project schedule rule count exceeded',
    ),
    bannerDescription: s__(
      'SecurityOrchestration|A scan execution policy exceeds the limit of %{maxScanExecutionPolicySchedules} scheduled rules per policy. Remove or consolidate rules across policies to reduce the total number of rules.',
    ),
  },
  name: 'ExceedingScheduledRulesBanner',
  components: {
    GlAlert,
    GlSprintf,
    LocalStorageSync,
  },
  inject: ['maxScanExecutionPolicySchedules'],
  emits: ['dismiss'],
  data() {
    return {
      alertDismissed: false,
    };
  },
  mounted() {
    this.emitChange();
  },
  methods: {
    dismissAlert() {
      this.alertDismissed = true;
      this.emitChange();
    },
    emitChange() {
      this.$emit('dismiss', this.alertDismissed);
    },
  },
};
</script>

<template>
  <local-storage-sync v-model="alertDismissed" :storage-key="$options.BANNER_STORAGE_KEY">
    <gl-alert
      v-if="!alertDismissed"
      :title="$options.i18n.bannerTitle"
      :dismissible="true"
      variant="danger"
      @dismiss="dismissAlert"
    >
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.bannerDescription">
          <template #maxScanExecutionPolicySchedules>
            <strong>{{ maxScanExecutionPolicySchedules }}</strong>
          </template>
        </gl-sprintf>
      </p>
    </gl-alert>
  </local-storage-sync>
</template>
