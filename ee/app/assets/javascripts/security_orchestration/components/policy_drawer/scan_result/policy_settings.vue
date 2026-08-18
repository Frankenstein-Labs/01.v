<script>
import { s__ } from '~/locale';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION,
  SETTINGS_HUMANIZED_STRINGS,
} from '../../policy_editor/scan_result/lib/settings';
import BlockGroupBranchModificationSetting from './block_group_branch_modification_setting.vue';

export default {
  name: 'PolicySettings',
  i18n: {
    title: s__('SecurityOrchestration|Override the following project settings:'),
  },
  components: {
    BlockGroupBranchModificationSetting,
  },
  props: {
    settings: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasSettings() {
      return Boolean(this.settingsList.length);
    },
    settingsList() {
      return Object.entries(this.settings).filter(this.isValidSetting).map(this.formatSettingItem);
    },
  },
  methods: {
    isGroupBranchModSettingWithExceptions(key, value) {
      return key === BLOCK_GROUP_BRANCH_MODIFICATION && value?.enabled;
    },
    isValidBranchModificationSetting(key, value) {
      return key === BLOCK_GROUP_BRANCH_MODIFICATION && typeof value !== 'boolean' && value.enabled;
    },
    isValidStandardSetting(key) {
      return this.settings[key] && Boolean(SETTINGS_HUMANIZED_STRINGS[key]);
    },
    isValidSetting([key, value]) {
      return this.isValidStandardSetting(key) || this.isValidBranchModificationSetting(key, value);
    },
    formatSettingItem([key, value]) {
      return {
        key,
        text: SETTINGS_HUMANIZED_STRINGS[key],
        value,
      };
    },
  },
};
</script>

<template>
  <div v-if="hasSettings" class="gl-mt-5">
    <h5>{{ $options.i18n.title }}</h5>
    <ul>
      <li v-for="{ key, text, value } in settingsList" :key="key" class="gl-mb-2">
        {{ text }}
        <block-group-branch-modification-setting
          v-if="isGroupBranchModSettingWithExceptions(key, value)"
          :exceptions="value.exceptions"
        />
      </li>
    </ul>
  </div>
</template>
