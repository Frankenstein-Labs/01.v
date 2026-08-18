<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { SCAN_PROFILE_CATEGORIES } from '~/security_configuration/constants';

export default {
  name: 'SecurityConfigurationBreadcrumb',
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      type: Array,
      required: true,
    },
  },
  computed: {
    breadcrumbs() {
      const securityConfigurationCrumb = {
        text: s__('SecurityConfiguration|Security configuration'),
        to: '/',
      };

      if (this.$route.name === 'scanner_details') {
        const key = this.$route.params.scanner_key;
        return [
          ...this.staticBreadcrumbs,
          securityConfigurationCrumb,
          {
            text: sprintf(s__('SecurityConfiguration|%{scanner} configuration'), {
              scanner: SCAN_PROFILE_CATEGORIES[key]?.name ?? key,
            }),
            to: this.$route.path,
          },
        ];
      }

      return [...this.staticBreadcrumbs, securityConfigurationCrumb];
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="breadcrumbs" />
</template>
