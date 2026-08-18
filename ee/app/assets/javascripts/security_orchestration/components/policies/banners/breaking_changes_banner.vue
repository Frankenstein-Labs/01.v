<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import { s__ } from '~/locale';

export default {
  MATCH_ON_INCLUSION_PATH: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
    {
      anchor: 'license_finding-rule-type',
    },
  ),
  SCAN_FINDING_TYPE_PATH: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
    {
      anchor: 'scan_finding-rule-type',
    },
  ),
  MERGE_REQUEST_APPROVAL_PATH: helpPagePath(
    'user/application_security/policies/merge_request_approval_policies',
    {
      anchor: 'merge-request-approval-policies-schema',
    },
  ),
  BANNER_STORAGE_KEY: 'security_policies_breaking_changes_18',
  i18n: {
    bannerTitle: s__('SecurityOrchestration|Merge request approval policy syntax changes'),
    bannerDescription: s__(
      'SecurityOrchestration|Several merge request approval policy criteria have been deprecated. Policies using these criteria will not work after GitLab 18.0 (May 10, 2025). You must edit these policies to replace or remove the deprecated criteria.',
    ),
    bannerSubheader: s__('SecurityOrchestration|Summary of syntax changes:'),
    policyNameChange: s__(
      'SecurityOrchestration|type: scan_result_policy is replaced with %{linkStart}type: approval_policy%{linkEnd}',
    ),
  },
  name: 'BreakingChangesBanner',
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
      <p>{{ $options.i18n.bannerDescription }}</p>
      <p>{{ $options.i18n.bannerSubheader }}</p>

      <ul class="gl-mb-0">
        <li>
          <gl-sprintf :message="$options.i18n.policyNameChange">
            <template #link="{ content }">
              <gl-link :href="$options.MERGE_REQUEST_APPROVAL_PATH" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
        </li>
      </ul>
    </gl-alert>
  </local-storage-sync>
</template>
