<script>
import { GlNavItem, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'HelpCenterUpgradeSubscription',
  components: {
    GlNavItem,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    upgradeSubscription: __('Upgrade subscription'),
  },
  inject: ['isIconOnly'],
  props: {
    upgradeLink: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <gl-nav-item
    v-gl-tooltip.right="isIconOnly ? $options.i18n.upgradeSubscription : ''"
    :is-icon-only="isIconOnly"
    icon="license"
    data-track-action="click_button"
    data-track-label="upgrade_subscription"
    data-track-property="nav_upgrade_subscription"
    :aria-label="$options.i18n.upgradeSubscription"
    :href="upgradeLink"
  >
    {{ $options.i18n.upgradeSubscription }}
  </gl-nav-item>
</template>
