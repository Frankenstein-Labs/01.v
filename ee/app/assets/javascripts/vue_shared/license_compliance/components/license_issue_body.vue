<script>
import { GlLink } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';

import { CLICK_EXTERNAL_LINK_LICENSE_COMPLIANCE } from '../constants';
import LicensePackages from './license_packages.vue';

export default {
  name: 'LicenseIssueBody',
  components: { LicensePackages, GlLink },
  mixins: [InternalEvents.mixin()],
  props: {
    issue: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasPackages() {
      return Boolean(this.issue.packages.length);
    },
  },
  methods: {
    trackLinkClick() {
      this.trackEvent(CLICK_EXTERNAL_LINK_LICENSE_COMPLIANCE);
    },
  },
};
</script>

<template>
  <div class="report-block-info license-item">
    <gl-link v-if="issue.url" :href="issue.url" target="_blank" @click="trackLinkClick">{{
      issue.name
    }}</gl-link>
    <span v-else data-testid="license-copy">{{ issue.name }}</span>
    <license-packages v-if="hasPackages" :packages="issue.packages" class="gl-text-subtle" />
  </div>
</template>
