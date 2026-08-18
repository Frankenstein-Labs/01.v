<script>
import { GlButton } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { getPackagesString } from '../store/utils';

export default {
  name: 'LicensePackages',
  components: {
    GlButton,
  },
  props: {
    packages: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      displayPackageCount: 3,
      showAllPackages: false,
    };
  },
  computed: {
    packageString() {
      return getPackagesString(this.packages, !this.showAllPackages, this.displayPackageCount);
    },
    remainingPackages() {
      const { packages } = this;
      if (packages.length > this.displayPackageCount) {
        return sprintf(s__('ciReport|%{remainingPackagesCount} more'), {
          remainingPackagesCount: packages.length - this.displayPackageCount,
        });
      }
      return '';
    },
  },
  methods: {
    handleShowPackages() {
      this.showAllPackages = true;
    },
  },
};
</script>
<template>
  <div class="license-packages gl-inline gl-text-sm">
    <div class="js-license-dependencies gl-inline">{{ packageString }}</div>
    <gl-button
      v-if="!showAllPackages && remainingPackages"
      variant="link"
      class="btn-show-all-packages"
      @click="handleShowPackages"
    >
      {{ remainingPackages }}
    </gl-button>
  </div>
</template>
