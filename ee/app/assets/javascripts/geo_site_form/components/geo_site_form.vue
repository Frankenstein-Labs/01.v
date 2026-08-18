<script>
import { GlButton } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapGetters, mapState } from 'vuex';
import { __ } from '~/locale';
import { visitUrl } from '~/lib/utils/url_utility';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import GeoSiteFormCapacities from './geo_site_form_capacities.vue';
import GeoSiteFormCore from './geo_site_form_core.vue';
import GeoSiteFormSelectiveSync from './geo_site_form_selective_sync.vue';

export default {
  name: 'GeoSiteForm',
  i18n: {
    saveChanges: __('Save changes'),
    cancel: __('Cancel'),
  },
  components: {
    GlButton,
    GeoSiteFormCore,
    GeoSiteFormSelectiveSync,
    GeoSiteFormCapacities,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    site: {
      type: Object,
      required: false,
      default: null,
    },
    selectiveSyncTypes: {
      type: Object,
      required: true,
    },
    syncShardsOptions: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      siteData: {
        name: '',
        url: '',
        primary: false,
        internalUrl: '',
        selectiveSyncType: '',
        selectiveSyncNamespaceIds: [],
        selectiveSyncShards: [],
        selectiveSyncOrganizationIds: [],
        reposMaxCapacity: 25,
        filesMaxCapacity: 10,
        verificationMaxCapacity: 100,
        containerRepositoriesMaxCapacity: 10,
        minimumReverificationInterval: 7,
        syncObjectStorage: false,
      },
    };
  },
  computed: {
    ...mapGetters(['formHasError']),
    ...mapState(['sitesPath']),
    showSelectiveSyncForm() {
      return (
        this.glFeatures.orgMoverExtendSelectiveSyncToPrimaryChecksumming || !this.siteData.primary
      );
    },
  },
  created() {
    if (this.site) {
      const selectiveSyncType = this.site.selectiveSyncType ?? '';
      this.siteData = { ...this.site, selectiveSyncType };
    }
  },
  methods: {
    ...mapActions(['saveGeoSite']),
    redirect() {
      visitUrl(this.sitesPath);
    },
    updateSyncOptions({ key, value }) {
      this.siteData[key] = value;
    },
  },
};
</script>

<template>
  <form>
    <geo-site-form-core
      :site-data="siteData"
      class="gl-border-b-1 gl-border-b-default gl-pb-4 gl-border-b-solid"
    />
    <geo-site-form-selective-sync
      v-if="showSelectiveSyncForm"
      class="gl-border-b-1 gl-border-b-default gl-pb-4 gl-border-b-solid"
      :site-data="siteData"
      :selective-sync-types="selectiveSyncTypes"
      :sync-shards-options="syncShardsOptions"
      @update-sync-options="updateSyncOptions"
    />
    <geo-site-form-capacities :site-data="siteData" />
    <section
      class="gl-mt-6 gl-flex gl-items-center gl-border-t-1 gl-border-default gl-py-5 gl-border-t-solid"
    >
      <gl-button
        id="site-save-button"
        data-testid="add-site-button"
        class="gl-mr-3"
        variant="confirm"
        :disabled="formHasError"
        @click="saveGeoSite(siteData)"
        >{{ $options.i18n.saveChanges }}</gl-button
      >
      <gl-button id="site-cancel-button" @click="redirect">{{ $options.i18n.cancel }}</gl-button>
    </section>
  </form>
</template>
