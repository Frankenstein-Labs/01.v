<script>
import { GlDisclosureDropdown, GlDisclosureDropdownItem, GlDropdownDivider } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  SCAN_PROFILE_I18N,
  SCAN_PROFILE_SCANNER_HEALTH_FAILED,
  SCAN_PROFILE_SCANNER_HEALTH_WARNING,
} from '~/security_configuration/constants';

export default {
  name: 'ActionsCell',
  components: {
    GlDisclosureDropdown,
    GlDisclosureDropdownItem,
    GlDropdownDivider,
  },
  i18n: SCAN_PROFILE_I18N,
  props: {
    item: {
      type: Object,
      required: true,
    },
    hasProfile: {
      type: Boolean,
      required: true,
    },
  },
  emits: ['apply-profile', 'disable-profile', 'troubleshoot-failure'],
  computed: {
    isFailedOrWarning() {
      return (
        [SCAN_PROFILE_SCANNER_HEALTH_WARNING, SCAN_PROFILE_SCANNER_HEALTH_FAILED].includes(
          this.item?.scanStatus?.rawStatus,
        ) && Boolean(this.item?.scanStatus?.buildId)
      );
    },
    profileActions() {
      return this.hasProfile
        ? [
            {
              text: s__('SecurityConfiguration|Disable profile-based scanning'),
              action: () => this.$emit('disable-profile'),
            },
          ]
        : [
            {
              text: s__('SecurityConfiguration|Enable profile-based scanning'),
              action: () => this.$emit('apply-profile'),
            },
          ];
    },
    navigationActions() {
      return [
        {
          text: s__('SecurityConfiguration|View project configuration'),
          href: this.item.securityConfigurationPath,
        },
      ];
    },
  },
};
</script>
<template>
  <gl-disclosure-dropdown
    category="tertiary"
    variant="default"
    size="small"
    icon="ellipsis_v"
    no-caret
  >
    <gl-disclosure-dropdown-item
      v-if="isFailedOrWarning"
      data-testid="troubleshoot-failure-item"
      @action="$emit('troubleshoot-failure')"
    >
      <template #list-item>
        {{ $options.i18n.troubleshootFailure }}
      </template>
    </gl-disclosure-dropdown-item>
    <gl-disclosure-dropdown-item
      v-for="(action, index) in profileActions"
      :key="`profile-action-${index}`"
      :item="action"
    />
    <gl-dropdown-divider />
    <gl-disclosure-dropdown-item
      v-for="(action, index) in navigationActions"
      :key="`navigation-action-${index}`"
      :item="action"
    />
  </gl-disclosure-dropdown>
</template>
