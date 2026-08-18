<script>
import { GlPopover, GlLink } from '@gitlab/ui';
import { REPLICATION_STATUS_UI, REPLICATION_PAUSE_URL } from 'ee/geo_sites/constants';
import { __, s__ } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';

export default {
  name: 'GeoSiteReplicationStatus',
  i18n: {
    pauseHelpText: s__('Geo|Geo sites are paused using a command run on the site'),
    learnMore: __('Learn more'),
  },
  components: {
    GlPopover,
    GlLink,
    HelpIcon,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  computed: {
    replicationStatusUi() {
      if (this.site.dbReplicationLagSeconds !== null) {
        return this.site.enabled ? REPLICATION_STATUS_UI.enabled : REPLICATION_STATUS_UI.paused;
      }
      return REPLICATION_STATUS_UI.disabled;
    },
  },
  REPLICATION_PAUSE_URL,
};
</script>

<template>
  <div class="gl-flex gl-items-center">
    <span
      class="gl-font-bold"
      :class="replicationStatusUi.color"
      data-testid="replication-status-text"
      >{{ replicationStatusUi.text }}</span
    >
    <help-icon ref="replicationStatus" class="gl-ml-2" />
    <gl-popover
      :target="() => $refs.replicationStatus && $refs.replicationStatus.$el"
      placement="top"
      triggers="hover focus"
    >
      <p class="gl-text-base">
        {{ $options.i18n.pauseHelpText }}
      </p>
      <gl-link :href="$options.REPLICATION_PAUSE_URL" target="_blank">{{
        $options.i18n.learnMore
      }}</gl-link>
    </gl-popover>
  </div>
</template>
