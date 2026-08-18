<script>
import { GlCard } from '@gitlab/ui';
import { parseSeconds, stringifyTime } from '~/lib/utils/datetime_utility';
import { __, s__ } from '~/locale';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';

export default {
  name: 'GeoSiteSecondaryOtherInfo',
  i18n: {
    otherInfo: __('Other information'),
    dbReplicationLag: s__('Geo|Data replication lag'),
    lastEventId: s__('Geo|Last event ID from primary'),
    lastCursorEventId: s__('Geo|Last event ID processed'),
    storageConfig: s__('Geo|Storage config'),
    shardsNotMatched: s__('Geo|Does not match the primary storage configuration'),
    unknown: __('Unknown'),
    ok: __('OK'),
    nA: __('Not applicable.'),
  },
  classTimestamp: 'gl-text-subtle gl-text-sm gl-font-normal',
  components: {
    GlCard,
    TimeAgo,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  computed: {
    storageShardsStatus() {
      if (this.site.storageShardsMatch == null) {
        return this.$options.i18n.unknown;
      }

      return this.site.storageShardsMatch
        ? this.$options.i18n.ok
        : this.$options.i18n.shardsNotMatched;
    },
    dbReplicationLag() {
      if (this.site.enabled && parseInt(this.site.dbReplicationLagSeconds, 10) >= 0) {
        const parsedTime = parseSeconds(this.site.dbReplicationLagSeconds, {
          hoursPerDay: 24,
          daysPerWeek: 7,
        });

        return stringifyTime(parsedTime);
      }

      return this.$options.i18n.nA;
    },
    lastEventTimestamp() {
      // Converting timestamp to ms
      return this.site.lastEventTimestamp * 1000;
    },
    lastCursorEventTimestamp() {
      // Converting timestamp to ms
      return this.site.cursorLastEventTimestamp * 1000;
    },
    hasEventInfo() {
      return this.site.lastEventId || this.lastEventTimestamp;
    },
    hasCursorEventInfo() {
      return this.site.cursorLastEventId || this.lastCursorEventTimestamp;
    },
  },
};
</script>

<template>
  <gl-card>
    <template #header>
      <h5 class="gl-my-0">{{ $options.i18n.otherInfo }}</h5>
    </template>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.dbReplicationLag }}</span>
      <span class="gl-mt-2 gl-font-bold" data-testid="replication-lag">{{ dbReplicationLag }}</span>
    </div>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.lastEventId }}</span>
      <div class="gl-mt-2 gl-font-bold" data-testid="last-event">
        <template v-if="hasEventInfo">
          <span v-if="site.lastEventId">{{ site.lastEventId }}</span>
          <span v-if="lastEventTimestamp" :class="$options.classTimestamp">
            <time-ago :time="lastEventTimestamp" />
          </span>
        </template>
        <span v-else>{{ $options.i18n.unknown }}</span>
      </div>
    </div>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.lastCursorEventId }}</span>
      <div class="gl-mt-2 gl-font-bold" data-testid="last-cursor-event">
        <template v-if="hasCursorEventInfo">
          <span v-if="site.cursorLastEventId">{{ site.cursorLastEventId }}</span>
          <span v-if="lastCursorEventTimestamp" :class="$options.classTimestamp">
            <time-ago :time="lastCursorEventTimestamp" />
          </span>
        </template>
        <span v-else>{{ $options.i18n.unknown }}</span>
      </div>
    </div>
    <div class="gl-mb-5 gl-flex gl-flex-col">
      <span>{{ $options.i18n.storageConfig }}</span>
      <span class="gl-mt-2 gl-font-bold" data-testid="storage-shards">{{
        storageShardsStatus
      }}</span>
    </div>
  </gl-card>
</template>
