<script>
import { GlAccordion } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { s__ } from '~/locale';
import { getBaseURL, joinPaths } from '~/lib/utils/url_utility';
import {
  MERGE_REQUEST_CONFIGURATION_KEYS,
  PROJECT_WIDE_CONFIGURATION_KEYS,
  BLOCK_BRANCH_MODIFICATION,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import SettingsItem from './settings_item.vue';

export default {
  name: 'SettingsSection',
  i18n: {
    emptyMessage: s__('ScanResultPolicy|No settings available for this policy'),
    protectedBranchTitle: s__('ScanResultPolicy|Protected branch settings'),
    mergeRequestTitle: s__('ScanResultPolicy|Merge request approval settings'),
    protectedBranchesDescription: s__(
      'ScanResultPolicy|If selected, the following choices will overwrite %{linkStart}project settings%{linkEnd} but only affect the branches selected in the policy.',
    ),
    mergeRequestDescription: s__(
      'ScanResultPolicy|If selected, the following choices will overwrite %{linkStart}project settings%{linkEnd} for approval rules created by this policy.',
    ),
    projectWideTitle: s__('ScanResultPolicy|Project-wide settings'),
    projectWideDescription: s__(
      'ScanResultPolicy|Always applied while this policy is active, regardless of branches or violations.',
    ),
  },
  components: {
    GlAccordion,
    SettingsItem,
  },
  inject: ['namespacePath'],
  props: {
    rules: {
      type: Array,
      required: false,
      default: () => [],
    },
    settings: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['changed'],
  computed: {
    protectedBranchSettings() {
      const basicSettings = this.groupSettingsBy([
        PREVENT_PUSHING_AND_FORCE_PUSHING,
        BLOCK_BRANCH_MODIFICATION,
      ]);
      const blockGroupBranchSettings = this.groupSettingsBy([BLOCK_GROUP_BRANCH_MODIFICATION]);

      /**
       * blockGroupBranchSettings must be at the end of the list
       */
      return {
        ...basicSettings,
        ...blockGroupBranchSettings,
      };
    },
    mergeRequestSettings() {
      return this.groupSettingsBy(MERGE_REQUEST_CONFIGURATION_KEYS);
    },
    projectWideSettings() {
      return this.groupSettingsBy(PROJECT_WIDE_CONFIGURATION_KEYS);
    },
    protectedBranchesSettingLink() {
      return joinPaths(getBaseURL(), this.namespacePath, '-', 'settings/repository');
    },
    mergeRequestSettingLink() {
      return joinPaths(getBaseURL(), this.namespacePath, '-', 'settings/merge_requests');
    },
    areAllSettingsEmpty() {
      return (
        this.isSettingsEmpty(this.protectedBranchSettings) &&
        this.isSettingsEmpty(this.mergeRequestSettings) &&
        this.isSettingsEmpty(this.projectWideSettings)
      );
    },
  },
  methods: {
    updateSetting({ key, value }) {
      const updates = { [key]: value };
      this.updatePolicy(updates);
    },
    updatePolicy(updates = {}) {
      this.$emit('changed', { ...this.settings, ...updates });
    },
    groupSettingsBy(groupNameKeys) {
      return Object.entries(this.settings).reduce((acc, [key, setting]) => {
        if (groupNameKeys.includes(key)) {
          acc[key] = setting;
        }

        return acc;
      }, {});
    },
    isSettingsEmpty(settings) {
      return isEmpty(settings);
    },
  },
};
</script>

<template>
  <div class="gl-mb-3">
    <gl-accordion :header-level="3">
      <div v-if="areAllSettingsEmpty" data-testid="empty-state">
        {{ $options.i18n.emptyMessage }}
      </div>
      <settings-item
        v-if="!isSettingsEmpty(protectedBranchSettings)"
        data-testid="protected-branches-setting"
        :description="$options.i18n.protectedBranchesDescription"
        :link="protectedBranchesSettingLink"
        :title="$options.i18n.protectedBranchTitle"
        :rules="rules"
        :settings="protectedBranchSettings"
        @update="updateSetting"
      />
      <settings-item
        v-if="!isSettingsEmpty(mergeRequestSettings)"
        data-testid="merge-request-setting"
        :description="$options.i18n.mergeRequestDescription"
        :link="mergeRequestSettingLink"
        :title="$options.i18n.mergeRequestTitle"
        :settings="mergeRequestSettings"
        @update="updateSetting"
      />
      <settings-item
        v-if="!isSettingsEmpty(projectWideSettings)"
        data-testid="project-wide-setting"
        :description="$options.i18n.projectWideDescription"
        :title="$options.i18n.projectWideTitle"
        :settings="projectWideSettings"
        @update="updateSetting"
      />
    </gl-accordion>
  </div>
</template>
