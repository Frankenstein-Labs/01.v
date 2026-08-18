<script>
import { GlAccordionItem, GlFormCheckbox, GlTooltipDirective, GlLink, GlSprintf } from '@gitlab/ui';
import {
  BLOCK_BRANCH_MODIFICATION,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  SETTINGS_HUMANIZED_STRINGS,
  SETTINGS_LINKS,
  SETTINGS_POPOVER_STRINGS,
  SETTINGS_TOOLTIP,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';
import { ALL_PROTECTED_BRANCHES } from 'ee/security_orchestration/components/policy_editor/constants';
import { isProject } from 'ee/security_orchestration/components/utils';
import SettingPopover from './setting_popover.vue';
import BlockGroupBranchModification from './block_group_branch_modification.vue';

export default {
  SETTINGS_LINKS,
  SETTINGS_HUMANIZED_STRINGS,
  SETTINGS_TOOLTIP,
  SETTINGS_POPOVER_STRINGS,
  name: 'SettingsItem',
  components: {
    BlockGroupBranchModification,
    GlAccordionItem,
    GlFormCheckbox,
    GlLink,
    GlSprintf,
    SettingPopover,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['namespaceType'],
  props: {
    title: {
      type: String,
      required: false,
      default: '',
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    link: {
      type: String,
      required: false,
      default: '',
    },
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
    visible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['update'],
  computed: {
    isProject() {
      return isProject(this.namespaceType);
    },
    showLink() {
      return this.isProject && Boolean(this.link);
    },
    isProtectedBranchesSelected() {
      return this.rules.some(
        (rule) => rule.branch_type === ALL_PROTECTED_BRANCHES.value || rule.branches,
      );
    },
  },
  methods: {
    getExceptions(value) {
      return value?.exceptions;
    },
    getSettingValue(setting) {
      return this.settings[setting] || false;
    },
    getEnabled(value) {
      return value?.enabled || value;
    },
    hasSpecialComponent(value) {
      return value === BLOCK_GROUP_BRANCH_MODIFICATION;
    },
    showPopover(setting) {
      switch (setting) {
        case BLOCK_BRANCH_MODIFICATION:
        default:
          return this.isProtectedBranchesSelected && !this.getSettingValue(setting);
      }
    },
    updateSetting(key, value) {
      this.$emit('update', { key, value });
    },
  },
};
</script>

<template>
  <gl-accordion-item :visible="visible" :title="title">
    <p v-if="description" class="gl-mb-3">
      <gl-sprintf :message="description">
        <template #link="{ content }">
          <gl-link v-if="showLink" :href="link" target="_blank" data-testid="settings-project-link">
            {{ content }}</gl-link
          >
          <span v-else data-testid="settings-group-text">{{ content }}</span>
        </template>
      </gl-sprintf>
    </p>

    <div v-for="(value, key) in settings" :key="key">
      <span v-gl-tooltip.viewport.hover.right :title="$options.SETTINGS_TOOLTIP[key]">
        <gl-form-checkbox
          :id="key"
          class="gl-inline-block"
          :checked="getEnabled(value)"
          @change="updateSetting(key, $event)"
        />
        <span v-if="hasSpecialComponent(key)">
          <block-group-branch-modification
            class="gl-inline-block"
            :enabled="getEnabled(value)"
            :exceptions="getExceptions(value)"
            @change="updateSetting(key, $event)"
          >
            {{ $options.SETTINGS_HUMANIZED_STRINGS[key] }}
          </block-group-branch-modification>
        </span>
        <span v-else>
          {{ $options.SETTINGS_HUMANIZED_STRINGS[key] }}
        </span>
      </span>

      <setting-popover
        v-if="$options.SETTINGS_POPOVER_STRINGS[key]"
        :id="key"
        :data-testid="`${key}-popover`"
        :description="$options.SETTINGS_POPOVER_STRINGS[key].description"
        :feature-name="$options.SETTINGS_POPOVER_STRINGS[key].featureName"
        :link="$options.SETTINGS_LINKS[key]"
        :show-popover="showPopover(key)"
        :title="$options.SETTINGS_POPOVER_STRINGS[key].title"
      />
    </div>
  </gl-accordion-item>
</template>
