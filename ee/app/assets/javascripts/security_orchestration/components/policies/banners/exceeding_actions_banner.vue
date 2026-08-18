<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';
import { ACTION_LIMIT } from 'ee/security_orchestration/components/policies/constants';

export default {
  ACTION_LIMIT,
  SCAN_EXECUTION_ACTION_LIMIT_PATH: helpPagePath(
    'user/application_security/policies/scan_execution_policies',
  ),
  BANNER_STORAGE_KEY: 'security_policies_exceeding_actions_18',
  i18n: {
    bannerTitle: s__(
      'SecurityOrchestration|Maximum action limit for scan execution policies exceeded',
    ),
    bannerDescription: s__(
      'SecurityOrchestration|A scan execution policy exceeds the limit of %{maxCount} actions per policy. Remove or separate out actions across multiple policies to reduce the number of actions in one policy.',
    ),
  },
  name: 'ExceedingActionsBanner',
  components: {
    GlAlert,
    GlLink,
    GlSprintf,
    LocalStorageSync,
  },
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
      :dismissible="true"
      :title="$options.i18n.bannerTitle"
      variant="danger"
      @dismiss="dismissAlert"
    >
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.bannerDescription">
          <template #link="{ content }">
            <gl-link :href="$options.SCAN_EXECUTION_ACTION_LIMIT_PATH" target="_blank">{{
              content
            }}</gl-link>
          </template>
          <template #maxCount>
            {{ $options.ACTION_LIMIT }}
          </template>
        </gl-sprintf>
      </p>
    </gl-alert>
  </local-storage-sync>
</template>
