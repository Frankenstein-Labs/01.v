<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { VIEW_ADMIN_GEO_SETTINGS_PAGELOAD } from 'ee/geo_settings/constants';
import { InternalEvents } from '~/tracking';
import GeoSettingsForm from './geo_settings_form.vue';

export default {
  name: 'GeoSettingsApp',
  i18n: {
    geoSettingsTitle: s__('Geo|Geo Settings'),
    geoSettingsSubtitle: s__(
      'Geo|Set the timeout in seconds to send a secondary site status to the primary and IPs allowed for the secondary sites.',
    ),
  },
  components: {
    GlLoadingIcon,
    GeoSettingsForm,
    PageHeading,
  },
  mixins: [InternalEvents.mixin()],
  computed: {
    ...mapState(['isLoading']),
  },
  created() {
    this.fetchGeoSettings();
  },
  mounted() {
    this.trackEvent(VIEW_ADMIN_GEO_SETTINGS_PAGELOAD);
  },
  methods: {
    ...mapActions(['fetchGeoSettings']),
  },
};
</script>

<template>
  <article data-testid="geoSettingsContainer">
    <page-heading :heading="$options.i18n.geoSettingsTitle">
      <template #description>
        {{ $options.i18n.geoSettingsSubtitle }}
      </template>
    </page-heading>
    <gl-loading-icon v-if="isLoading" size="xl" />
    <geo-settings-form v-else />
  </article>
</template>
