<script>
import { GlIcon, GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isProjectLevelSettingOverridden } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

export default {
  i18n: {
    title: s__('SecurityOrchestration|Policy override'),
    popoverTextGeneric: s__(
      'SecurityOrchestration|Default approval settings on this merge request have been overridden by policies based on their rules.',
    ),
    popoverTextSingle: s__(
      'SecurityOrchestration|Default approval settings on this merge request have been overridden by policy %{policyName} based on its rules.',
    ),
    popoverTextMultiple: s__(
      'SecurityOrchestration|Default approval settings on this merge request have been overridden by the following policies based on their rules:',
    ),
  },
  name: 'PolicyApprovalSettingsIcon',
  components: {
    GlIcon,
    GlLink,
    GlPopover,
    GlSprintf,
  },
  props: {
    policies: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    policiesWithMergeRequestSettingsOverride() {
      return (this.policies || []).filter(({ settings = {} }) =>
        Object.entries(settings).some(([setting, value]) =>
          isProjectLevelSettingOverridden(setting, value),
        ),
      );
    },
    // TODO: Temporary to handle policies without details
    // Remove when backfill from https://gitlab.com/gitlab-org/gitlab/-/merge_requests/173714 is finished
    showPolicyDetails() {
      return (this.policies || []).every(
        (policy) => Boolean(policy.name) && Boolean(policy.editPath),
      );
    },
    hasPoliciesOverridingApprovalSettings() {
      return this.policiesWithMergeRequestSettingsOverride.length > 0;
    },
    hasMultiplePolicies() {
      return this.policiesWithMergeRequestSettingsOverride.length > 1;
    },
  },
};
</script>

<template>
  <div v-if="hasPoliciesOverridingApprovalSettings">
    <gl-popover
      :title="$options.i18n.title"
      target="policy-override-warning-icon"
      show-close-button
    >
      <template v-if="showPolicyDetails">
        <template v-if="hasMultiplePolicies">
          {{ $options.i18n.popoverTextMultiple }}
          <ul class="gl-pl-5">
            <li v-for="(policy, index) in policiesWithMergeRequestSettingsOverride" :key="index">
              <gl-link
                :href="policy.editPath"
                target="_blank"
                :data-testid="`policy-item-${index}`"
              >
                {{ policy.name }}
              </gl-link>
            </li>
          </ul>
        </template>
        <template v-else>
          <gl-sprintf :message="$options.i18n.popoverTextSingle">
            <template #policyName>
              <gl-link :href="policiesWithMergeRequestSettingsOverride[0].editPath" target="_blank">
                {{ policiesWithMergeRequestSettingsOverride[0].name }}
              </gl-link>
            </template>
          </gl-sprintf>
        </template>
      </template>
      <template v-else>
        {{ $options.i18n.popoverTextGeneric }}
      </template>
    </gl-popover>

    <gl-icon id="policy-override-warning-icon" name="warning" />
  </div>
</template>
