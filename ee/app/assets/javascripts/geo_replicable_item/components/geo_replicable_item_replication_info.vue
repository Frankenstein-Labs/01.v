<script>
import { GlSprintf, GlBadge, GlCard, GlPopover, GlButton } from '@gitlab/ui';
import { REPLICATION_STATUS_STATES } from 'ee/geo_shared/constants';
import { __, s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'GeoReplicableItemReplicationInfo',
  components: {
    GlSprintf,
    GlBadge,
    GlCard,
    GlPopover,
    GlButton,
    TimeAgo,
    HelpIcon,
    HelpPageLink,
  },
  props: {
    replicableItem: {
      type: Object,
      required: true,
    },
  },
  emits: ['resync'],
  i18n: {
    replicationInformation: s__('Geo|Replication information'),
    replicationHelpText: s__(
      'Geo|Shows the current replication status of this registry and whether it has encountered any issues during the replication process.',
    ),
    learnMore: __('Learn more'),
    resync: s__('Geo|Resync'),
    missingOnPrimary: s__('Geo|Missing on Primary!'),
    lastSyncedAt: s__('Geo|Last synced: %{timeAgo}'),
    syncRetryAt: s__(
      'Geo|%{noBoldStart}Next sync retry:%{noBoldEnd} Retry #%{retryCount} scheduled %{timeAgo}',
    ),
    statusBadge: s__('Geo|Status: %{badge}'),
    geoFailure: s__('Geo|Error: %{message}'),
    unknown: __('Unknown'),
  },
  computed: {
    replicationStatus() {
      return (
        REPLICATION_STATUS_STATES[this.replicableItem?.state] || REPLICATION_STATUS_STATES.UNKNOWN
      );
    },
    replicationFailure() {
      return this.replicableItem?.state === REPLICATION_STATUS_STATES.FAILED.value;
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <div class="gl-flex gl-items-center">
        <h5 class="gl-my-0">{{ $options.i18n.replicationInformation }}</h5>
        <help-icon id="replication-information-help-icon" class="gl-ml-2" />
        <gl-popover
          target="replication-information-help-icon"
          placement="top"
          triggers="hover focus"
        >
          <p>
            {{ $options.i18n.replicationHelpText }}
          </p>
          <help-page-link href="administration/geo/setup/database">{{
            $options.i18n.learnMore
          }}</help-page-link>
        </gl-popover>
        <gl-button class="gl-ml-auto" @click="$emit('resync')">{{
          $options.i18n.resync
        }}</gl-button>
      </div>
    </template>

    <div class="gl-flex gl-flex-col gl-gap-4">
      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.statusBadge">
          <template #badge>
            <gl-badge :variant="replicationStatus.variant">{{ replicationStatus.title }}</gl-badge>
          </template>
        </gl-sprintf>
      </p>

      <p v-if="replicableItem.missingOnPrimary" class="gl-mb-0 gl-font-bold gl-text-red-700">
        {{ $options.i18n.missingOnPrimary }}
      </p>

      <template v-if="replicationFailure">
        <p class="gl-mb-0">
          <gl-sprintf :message="$options.i18n.geoFailure">
            <template #message>
              <span class="gl-font-bold gl-text-red-700">{{
                replicableItem.lastSyncFailure || $options.i18n.unknown
              }}</span>
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0">
          <gl-sprintf :message="s__('Geo|Troubleshooting: %{link}')">
            <template #link>
              <help-page-link
                href="administration/geo/replication/troubleshooting/synchronization_verification"
                target="_blank"
                data-testid="replication-failure-troubleshooting-link"
                >{{ s__('Geo|View troubleshooting docs') }}</help-page-link
              >
            </template>
          </gl-sprintf>
        </p>

        <p class="gl-mb-0 gl-font-bold">
          <gl-sprintf :message="$options.i18n.syncRetryAt">
            <template #noBold="{ content }">
              <span class="gl-font-normal">{{ content }}</span>
            </template>
            <template #retryCount>
              <span>{{ replicableItem.retryCount }}</span>
            </template>
            <template #timeAgo>
              <time-ago :time="replicableItem.retryAt" data-testid="retry-at-time-ago" />
            </template>
          </gl-sprintf>
        </p>
      </template>

      <p class="gl-mb-0">
        <gl-sprintf :message="$options.i18n.lastSyncedAt">
          <template #timeAgo>
            <time-ago
              :time="replicableItem.lastSyncedAt"
              class="gl-font-bold"
              data-testid="last-synced-at-time-ago"
            />
          </template>
        </gl-sprintf>
      </p>
    </div>
  </gl-card>
</template>
