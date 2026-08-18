<script>
import GeoSiteProgressBar from 'ee/geo_sites/components/details/geo_site_progress_bar.vue';

export default {
  name: 'GeoSiteReplicationStatusMobile',
  components: {
    GeoSiteProgressBar,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    translations: {
      type: Object,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-5 gl-flex gl-flex-col" data-testid="sync-status">
      <span class="gl-mb-3 gl-text-sm">{{ translations.syncStatus }}</span>
      <geo-site-progress-bar
        :title="
          /* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */
          sprintf(translations.progressBarSyncTitle, {
            titlePlural: item.titlePlural,
          }) /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */
        "
        :target="`mobile-sync-progress-${item.namePlural}`"
        :values="item.syncValues"
      />
    </div>
    <div class="gl-flex gl-flex-col" data-testid="verification-status">
      <span class="gl-mb-3 gl-text-sm">{{ translations.verifStatus }}</span>
      <geo-site-progress-bar
        :title="
          /* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */
          sprintf(translations.progressBarVerifTitle, {
            titlePlural: item.titlePlural,
          }) /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */
        "
        :target="`mobile-verification-progress-${item.namePlural}`"
        :values="item.verificationValues"
        :success-label="translations.verified"
        :unavailable-label="translations.nothingToVerify"
      />
    </div>
  </div>
</template>
