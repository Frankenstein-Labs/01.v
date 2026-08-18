<script>
import { GlCard, GlPopover, GlLink, GlIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { HELP_INFO_URL } from 'ee/geo_sites/constants';
import { s__, __ } from '~/locale';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import GeoSiteProgressBar from '../geo_site_progress_bar.vue';

export default {
  name: 'GeoSiteVerificationInfo',
  i18n: {
    cardTitle: s__('Geo|Primary checksum progress'),
    replicationHelpText: s__(
      'Geo|Replicated data is verified with the secondary site(s) using checksums.',
    ),
    learnMore: __('Learn more'),
    checksummed: s__('Geo|Checksummed'),
    nothingToChecksum: s__('Geo|Nothing to checksum'),
  },
  components: {
    GlCard,
    GlPopover,
    GlLink,
    GlIcon,
    GeoSiteProgressBar,
    HelpIcon,
  },
  props: {
    site: {
      type: Object,
      required: true,
    },
  },
  computed: {
    ...mapGetters(['verificationInfo']),
    verificationInfoBars() {
      return this.verificationInfo(this.site.id);
    },
  },
  HELP_INFO_URL,
};
</script>

<template>
  <gl-card header-class="gl-flex gl-items-center">
    <template #header>
      <h5 class="gl-my-0">{{ $options.i18n.cardTitle }}</h5>
      <help-icon ref="verificationInfo" class="gl-ml-2" />
      <gl-popover
        :target="() => $refs.verificationInfo && $refs.verificationInfo.$el"
        placement="top"
        triggers="hover focus"
      >
        <p class="gl-text-base">
          {{ $options.i18n.replicationHelpText }}
        </p>
        <gl-link :href="$options.HELP_INFO_URL" target="_blank">{{
          $options.i18n.learnMore
        }}</gl-link>
      </gl-popover>
    </template>
    <gl-link
      v-for="bar in verificationInfoBars"
      :key="bar.namePlural"
      :href="bar.dataManagementUrl"
      data-testid="verification-bar-data-management-link"
      class="gl-flex gl-items-center gl-p-3 hover:gl-bg-gray-50"
    >
      <span class="gl-flex-1" data-testid="verification-bar-title">{{ bar.titlePlural }}</span>
      <geo-site-progress-bar
        class="gl-flex-1"
        :title="bar.titlePlural"
        :values="bar.values"
        :success-label="$options.i18n.checksummed"
        :unavailable-label="$options.i18n.nothingToChecksum"
      />
      <gl-icon name="chevron-right" class="gl-text-subtle" />
    </gl-link>
  </gl-card>
</template>
