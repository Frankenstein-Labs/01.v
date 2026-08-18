<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import GeoSiteActions from './geo_site_actions.vue';
import GeoSiteHealthStatus from './geo_site_health_status.vue';
import GeoSiteLastUpdated from './geo_site_last_updated.vue';

export default {
  name: 'GeoSiteHeader',
  i18n: {
    expand: __('Expand'),
    collapse: __('Collapse'),
  },
  components: {
    GlButton,
    GeoSiteHealthStatus,
    GeoSiteLastUpdated,
    GeoSiteActions,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
    collapsed: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['collapse'],
  computed: {
    chevronIcon() {
      return this.collapsed ? 'chevron-right' : 'chevron-down';
    },
    chevronLabel() {
      return this.collapsed ? this.$options.i18n.expand : this.$options.i18n.collapse;
    },
    statusCheckTimestamp() {
      return this.site.lastSuccessfulStatusCheckTimestamp
        ? this.site.lastSuccessfulStatusCheckTimestamp * 1000 // Converting timestamp to ms
        : null;
    },
  },
};
</script>

<template>
  <div
    class="geo-site-header-grid-columns gl-grid gl-border-b-1 gl-border-t-1 gl-border-b-default gl-border-t-default gl-bg-subtle gl-px-5 gl-py-3 gl-border-b-solid gl-border-t-solid"
  >
    <div class="gl-flex gl-items-center">
      <gl-button
        class="gl-mr-3 !gl-p-0"
        category="tertiary"
        variant="confirm"
        :icon="chevronIcon"
        :aria-label="chevronLabel"
        @click="$emit('collapse')"
      />
      <div class="gl-flex gl-grow gl-flex-col @md/panel:gl-flex-row @md/panel:gl-items-center">
        <div class="gl-flex gl-grow gl-basis-0 gl-items-center">
          <h4 class="gl-text-lg">{{ site.name }}</h4>
        </div>
        <div class="gl-flex gl-grow-2 gl-basis-0 gl-items-center">
          <geo-site-health-status :status="site.healthStatus" />
          <geo-site-last-updated
            v-if="statusCheckTimestamp"
            class="gl-ml-2"
            :status-check-timestamp="statusCheckTimestamp"
          />
        </div>
      </div>
    </div>
    <div class="gl-flex gl-items-center gl-justify-end">
      <geo-site-actions :site="site" />
    </div>
  </div>
</template>
