<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';

export default {
  PIPELINE_EXECUTION_POLICY_TYPE_PATH: helpPagePath(
    'user/application_security/policies/pipeline_execution_policies',
  ),
  BANNER_STORAGE_KEY: 'security_policies_deprecated_custom_scan_action_18',
  i18n: {
    bannerTitle: s__('SecurityOrchestration|Custom scan experiment has ended in 17.3'),
    bannerDescription: s__(
      'SecurityOrchestration|Scan execution policies using `custom` scan action have been detected. Policies using this action will not work after GitLab 18.0 (May 10, 2025). You must edit these policies to remove the deprecated action. Learn more about the %{linkStart}pipeline execution policy%{linkEnd}.',
    ),
  },
  name: 'DeprecatedCustomScanBanner',
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
      :title="$options.i18n.bannerTitle"
      :dismissible="true"
      @dismiss="dismissAlert"
    >
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.bannerDescription">
          <template #link="{ content }">
            <gl-link :href="$options.PIPELINE_EXECUTION_POLICY_TYPE_PATH" target="_blank">{{
              content
            }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
    </gl-alert>
  </local-storage-sync>
</template>
