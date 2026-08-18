<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { s__ } from '~/locale';
import GeoSiteReplicationSyncPercentage from './geo_site_replication_sync_percentage.vue';

export default {
  name: 'GeoSiteReplicationCounts',
  i18n: {
    dataType: s__('Geo|Data type'),
    synchronization: s__('Geo|Synchronization'),
    verification: s__('Geo|Verification'),
  },
  components: {
    GeoSiteReplicationSyncPercentage,
  },
  props: {
    siteId: {
      type: Number,
      required: true,
    },
  },
  computed: {
    ...mapGetters(['replicationCountsByDataTypeForSite']),
    replicationOverview() {
      return this.replicationCountsByDataTypeForSite(this.siteId);
    },
  },
};
</script>

<template>
  <div>
    <div class="geo-site-replication-counts-grid gl-mb-3 gl-grid gl-items-center">
      <span>{{ $options.i18n.dataType }}</span>
      <span class="gl-text-right">{{ $options.i18n.synchronization }}</span>
      <span class="gl-text-right">{{ $options.i18n.verification }}</span>
    </div>
    <div
      v-for="type in replicationOverview"
      :key="type.dataType"
      class="geo-site-replication-counts-grid gl-mb-3 gl-grid gl-items-center"
      data-testid="replication-type"
    >
      <span>{{ type.dataTypeTitle }}</span>
      <geo-site-replication-sync-percentage :values="type.sync" />
      <geo-site-replication-sync-percentage :values="type.verification" />
    </div>
  </div>
</template>
