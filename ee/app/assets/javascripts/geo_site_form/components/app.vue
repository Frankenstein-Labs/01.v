<script>
import { GlBadge, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { PRIMARY_SITE_SETTINGS, SECONDARY_SITE_SETTINGS } from '../constants';
import GeoSiteForm from './geo_site_form.vue';

export default {
  name: 'GeoSiteFormApp',
  i18n: {
    editGeoSite: s__('Geo|Edit Geo Site'),
    addGeoSite: s__('Geo|Add New Site'),
    primary: s__('Geo|Primary'),
    secondary: s__('Geo|Secondary'),
    subTitle: s__(
      'Geo|Configure various settings for your %{siteType} site. %{linkStart}Learn more%{linkEnd}',
    ),
  },
  components: {
    GeoSiteForm,
    GlBadge,
    GlSprintf,
    GlLink,
  },
  props: {
    selectiveSyncTypes: {
      type: Object,
      required: true,
    },
    syncShardsOptions: {
      type: Array,
      required: true,
    },
    site: {
      type: Object,
      required: false,
      default: null,
    },
  },
  computed: {
    isSitePrimary() {
      return this.site && this.site.primary;
    },
    pageTitle() {
      return this.site ? this.$options.i18n.editGeoSite : this.$options.i18n.addGeoSite;
    },
    pillDetails() {
      return {
        variant: this.isSitePrimary ? 'info' : 'neutral',
        label: this.isSitePrimary ? this.$options.i18n.primary : this.$options.i18n.secondary,
      };
    },
    pageSubtitle() {
      return {
        link: this.isSitePrimary ? PRIMARY_SITE_SETTINGS : SECONDARY_SITE_SETTINGS,
        siteType: this.isSitePrimary
          ? this.$options.i18n.primary.toLowerCase()
          : this.$options.i18n.secondary.toLowerCase(),
      };
    },
  },
};
</script>

<template>
  <article class="geo-site-form-container">
    <div class="gl-my-5">
      <div class="gl-flex gl-items-center gl-pb-3">
        <h2 class="gl-my-0 gl-text-size-h2">{{ pageTitle }}</h2>
        <gl-badge
          class="gl-ml-3 !gl-rounded-full gl-px-3 gl-py-2 gl-text-sm"
          :variant="pillDetails.variant"
          >{{ pillDetails.label }}</gl-badge
        >
      </div>
      <div data-testid="site-form-subtitle">
        <gl-sprintf :message="$options.i18n.subTitle">
          <template #siteType>
            <span>{{ pageSubtitle.siteType }}</span>
          </template>
          <template #link="{ content }">
            <gl-link :href="pageSubtitle.link" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </div>
    </div>
    <geo-site-form v-bind="$props" />
  </article>
</template>
