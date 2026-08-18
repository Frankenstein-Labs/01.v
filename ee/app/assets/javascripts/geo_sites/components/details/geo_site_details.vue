<script>
import GeoSiteCoreDetails from './geo_site_core_details.vue';
import GeoSitePrimaryOtherInfo from './primary_site/geo_site_primary_other_info.vue';
import GeoSiteVerificationInfo from './primary_site/geo_site_verification_info.vue';
import GeoSiteReplicationDetails from './secondary_site/geo_site_replication_details.vue';
import GeoSiteReplicationSummary from './secondary_site/geo_site_replication_summary.vue';
import GeoSiteSecondaryOtherInfo from './secondary_site/geo_site_secondary_other_info.vue';

export default {
  name: 'GeoSiteDetails',
  components: {
    GeoSiteCoreDetails,
    GeoSitePrimaryOtherInfo,
    GeoSiteVerificationInfo,
    GeoSiteReplicationSummary,
    GeoSiteSecondaryOtherInfo,
    GeoSiteReplicationDetails,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div class="geo-site-details-grid-columns gl-grid gl-p-5">
    <geo-site-core-details :site="site" />
    <div
      v-if="site.primary"
      class="gl-flex gl-h-full gl-w-full gl-flex-col gl-items-start @md/panel:gl-flex-row"
    >
      <geo-site-verification-info
        class="gl-mb-5 gl-h-full gl-w-full gl-grow @md/panel:gl-mb-0 @md/panel:gl-mr-5"
        :site="site"
      />
      <geo-site-primary-other-info class="gl-h-full gl-w-full gl-grow" :site="site" />
    </div>
    <div v-else class="gl-flex gl-h-full gl-w-full gl-flex-col">
      <div
        class="gl-mb-5 gl-flex gl-h-full gl-w-full gl-flex-col gl-items-start @md/panel:gl-flex-row"
      >
        <geo-site-replication-summary
          class="gl-mb-5 gl-h-full gl-w-full gl-grow @md/panel:gl-mb-0 @md/panel:gl-mr-5"
          :site="site"
        />
        <geo-site-secondary-other-info class="gl-h-full gl-w-full gl-grow" :site="site" />
      </div>
      <geo-site-replication-details :site="site" />
    </div>
  </div>
</template>
