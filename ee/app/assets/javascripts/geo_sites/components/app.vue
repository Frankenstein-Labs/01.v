<script>
import { GlButton, GlLoadingIcon, GlModal } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { s__, __ } from '~/locale';
import { InternalEvents } from '~/tracking';
import { REMOVE_SITE_MODAL_ID, VIEW_ADMIN_GEO_SITES_PAGELOAD } from '../constants';
import GeoSitesFilters from './geo_sites_filters.vue';
import GeoSites from './geo_sites.vue';
import GeoSitesEmptyState from './geo_sites_empty_state.vue';

export default {
  name: 'GeoSitesApp',
  i18n: {
    geoSites: s__('Geo|Geo sites'),
    helpText: s__(
      'Geo|With GitLab Geo, you can install a special read-only and replicated instance anywhere.',
    ),
    addSite: s__('Geo|Add site'),
    modalTitle: s__('Geo|Remove site'),
    modalBody: s__(
      'Geo|Removing a Geo site stops the synchronization to and from that site. Are you sure?',
    ),
    primarySite: s__('Geo|Primary site'),
    secondarySite: s__('Geo|Secondary site'),
    notConfiguredTitle: s__('Geo|Discover GitLab Geo'),
    notConfiguredDescription: s__(
      'Geo|Help your team work faster from any location. GitLab Geo creates read-only mirrors of your instance to clone and fetch large repositories quicker.',
    ),
    noResultsTitle: s__('Geo|No Geo site found'),
    noResultsDescription: s__('Geo|Edit your search and try again.'),
  },
  components: {
    PageHeading,
    GlButton,
    GlLoadingIcon,
    GeoSitesFilters,
    GeoSites,
    GeoSitesEmptyState,
    GlModal,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    newSiteUrl: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState(['sites', 'isLoading']),
    ...mapGetters(['filteredSites']),
    hasSites() {
      return this.sites && this.sites.length > 0;
    },
    hasEmptyState() {
      return Object.keys(this.emptyState).length;
    },
    primarySites() {
      return this.filteredSites.filter((n) => n.primary);
    },
    secondarySites() {
      return this.filteredSites.filter((n) => !n.primary);
    },
    emptyState() {
      // Geo isn't configured
      if (!this.hasSites) {
        return {
          title: this.$options.i18n.notConfiguredTitle,
          description: this.$options.i18n.notConfiguredDescription,
          showLearnMoreButton: true,
        };
        // User has searched and returned nothing
      }
      if (this.filteredSites.length === 0) {
        return {
          title: this.$options.i18n.noResultsTitle,
          description: this.$options.i18n.noResultsDescription,
          showLearnMoreButton: false,
        };
      }

      // Don't show empty state
      return {};
    },
  },
  created() {
    this.fetchSites();
  },
  mounted() {
    this.trackEvent(VIEW_ADMIN_GEO_SITES_PAGELOAD);
  },
  methods: {
    ...mapActions(['fetchSites', 'cancelSiteRemoval', 'removeSite']),
  },
  MODAL_PRIMARY_ACTION: {
    text: s__('Geo|Remove site'),
    attributes: {
      variant: 'danger',
    },
  },
  MODAL_CANCEL_ACTION: {
    text: __('Cancel'),
  },
  REMOVE_SITE_MODAL_ID,
};
</script>

<template>
  <section>
    <page-heading v-if="hasSites" :heading="$options.i18n.geoSites">
      <template #actions>
        <gl-button
          variant="confirm"
          :href="newSiteUrl"
          target="_blank"
          data-testid="add-site-button"
          >{{ $options.i18n.addSite }}
        </gl-button>
      </template>
      <template #description>
        {{ $options.i18n.helpText }}
      </template>
    </page-heading>
    <gl-loading-icon v-if="isLoading" size="xl" class="gl-mt-5" />
    <template v-if="!isLoading">
      <div v-if="hasSites">
        <geo-sites-filters :total-sites="sites.length" />
        <h4 v-if="primarySites.length" class="gl-my-5 gl-text-lg">
          {{ $options.i18n.primarySite }}
        </h4>
        <geo-sites
          v-for="site in primarySites"
          :key="site.id"
          :site="site"
          data-testid="primary-sites"
        />
        <h4 v-if="secondarySites.length" class="gl-my-5 gl-text-lg">
          {{ $options.i18n.secondarySite }}
        </h4>
        <geo-sites
          v-for="site in secondarySites"
          :key="site.id"
          :site="site"
          data-testid="secondary-sites"
        />
      </div>
      <geo-sites-empty-state
        v-if="hasEmptyState"
        :title="emptyState.title"
        :description="emptyState.description"
        :show-learn-more-button="emptyState.showLearnMoreButton"
      />
    </template>
    <gl-modal
      :modal-id="$options.REMOVE_SITE_MODAL_ID"
      :title="$options.i18n.modalTitle"
      :action-primary="$options.MODAL_PRIMARY_ACTION"
      :action-cancel="$options.MODAL_CANCEL_ACTION"
      @primary="removeSite"
      @cancel="cancelSiteRemoval"
    >
      {{ $options.i18n.modalBody }}
    </gl-modal>
  </section>
</template>
