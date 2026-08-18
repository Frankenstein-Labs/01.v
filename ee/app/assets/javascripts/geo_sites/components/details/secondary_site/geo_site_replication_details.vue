<script>
import { GlLink, GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { joinPaths } from '~/lib/utils/url_utility';
import GeoSiteReplicationDetailsResponsive from './geo_site_replication_details_responsive.vue';
import GeoSiteReplicationStatusMobile from './geo_site_replication_status_mobile.vue';

export default {
  name: 'GeoSiteReplicationDetails',
  components: {
    GlLink,
    GlButton,
    GeoSiteReplicationDetailsResponsive,
    GeoSiteReplicationStatusMobile,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      collapsed: false,
    };
  },
  computed: {
    ...mapGetters(['verificationInfo', 'syncInfo', 'sortedReplicableTypes']),
    replicationItems() {
      const syncInfoData = this.syncInfo(this.site.id);
      const verificationInfoData = this.verificationInfo(this.site.id);

      return this.sortedReplicableTypes.map(
        ({ namePlural, titlePlural, dataTypeTitle, replicationEnabled }) => {
          const replicableSyncInfo = syncInfoData.find((r) => r.namePlural === namePlural);

          const replicableVerificationInfo = verificationInfoData.find(
            (r) => r.namePlural === namePlural,
          );

          return {
            namePlural,
            dataTypeTitle,
            titlePlural,
            syncValues: replicableSyncInfo?.values,
            verificationValues: replicableVerificationInfo?.values,
            replicationView: replicationEnabled ? this.getReplicationView(namePlural) : null,
          };
        },
      );
    },
    chevronIcon() {
      return this.collapsed ? 'chevron-right' : 'chevron-down';
    },
  },
  methods: {
    collapseSection() {
      this.collapsed = !this.collapsed;
    },
    getReplicationView(namePlural) {
      return joinPaths(
        gon.relative_url_root || '/',
        `/admin/geo/sites/${this.site.id}/replication/${namePlural}`,
      );
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-border-t gl-border-b gl-py-5">
      <gl-button
        class="gl-mr-1 !gl-p-0"
        category="tertiary"
        variant="confirm"
        :icon="chevronIcon"
        @click="collapseSection"
      >
        {{ s__('Geo|Replication Details') }}
      </gl-button>
    </div>
    <div v-if="!collapsed">
      <geo-site-replication-details-responsive
        class="gl-hidden @md/panel:gl-block"
        :site-id="site.id"
        :replication-items="replicationItems"
        data-testid="geo-replication-details-desktop"
      />
      <geo-site-replication-details-responsive
        class="@md/panel:!gl-hidden"
        :site-id="site.id"
        :replication-items="replicationItems"
        data-testid="geo-replication-details-mobile"
      >
        <template #title="{ translations }">
          <span class="gl-font-bold">{{ translations.component }}</span>
          <span class="gl-font-bold">{{ translations.status }}</span>
        </template>
        <template #default="{ item, translations }">
          <div class="gl-mr-5" data-testid="replicable-component">
            <gl-link v-if="item.replicationView" :href="item.replicationView">{{
              item.titlePlural
            }}</gl-link>
            <span v-else>{{ item.titlePlural }}</span>
          </div>
          <geo-site-replication-status-mobile :item="item" :translations="translations" />
        </template>
      </geo-site-replication-details-responsive>
    </div>
  </div>
</template>
