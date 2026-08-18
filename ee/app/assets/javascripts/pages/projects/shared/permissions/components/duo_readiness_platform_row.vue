<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';
import { STATUS_DONE, STATUS_ERROR } from '~/pages/projects/shared/permissions/constants';

/**
 * Whether the Agent Platform is switched on above the project. Nothing else in the card can be
 * set up until it is, so this is the first row.
 */
export default {
  name: 'DuoReadinessPlatformRow',
  components: { DuoReadinessRow, GlButton },
  props: {
    readiness: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isEnabled() {
      return Boolean(this.readiness.platformEnabled);
    },
    // Where the switch actually lives: the group on SaaS, the instance otherwise.
    settingsPath() {
      return this.readiness.isSaas
        ? this.readiness.groupSettingsPath
        : this.readiness.adminSettingsPath;
    },
    description() {
      if (this.isEnabled) {
        return this.readiness.isSaas
          ? s__('DuoAgentPlatform|On for this group. Group Owners control it.')
          : s__('DuoAgentPlatform|On for this instance. Administrators control it.');
      }

      return this.readiness.isSaas
        ? s__('DuoAgentPlatform|Off for this group. Only a Group Owner can turn it on.')
        : s__('DuoAgentPlatform|Off for this instance. Only an administrator can turn it on.');
    },
    actionLabel() {
      if (this.isEnabled) return s__('DuoAgentPlatform|View');

      return this.readiness.isSaas
        ? s__('DuoAgentPlatform|Group settings')
        : s__('DuoAgentPlatform|Admin settings');
    },
  },
  i18n: {
    title: s__('DuoAgentPlatform|Agent Platform'),
  },
  STATUS_DONE,
  STATUS_ERROR,
};
</script>

<template>
  <duo-readiness-row
    :title="$options.i18n.title"
    :description="description"
    :status="isEnabled ? $options.STATUS_DONE : $options.STATUS_ERROR"
  >
    <gl-button
      v-if="settingsPath"
      :category="isEnabled ? 'tertiary' : 'secondary'"
      size="small"
      :href="settingsPath"
      target="_blank"
      data-testid="platform-row-action"
    >
      {{ actionLabel }}
    </gl-button>
  </duo-readiness-row>
</template>
