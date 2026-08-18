<script>
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import ProfilesList from './dast_profiles_list.vue';
import ScanTypeBadge from './dast_scan_type_badge.vue';

export default {
  name: 'DastScannerProfilesList',
  components: {
    ProfilesList,
    ScanTypeBadge,
  },
  mixins: [glListenersMixin],
};
</script>
<template>
  <profiles-list v-bind="$attrs" v-on="glListeners()">
    <template #cell(scanType)="{ value }">
      <scan-type-badge :scan-type="value" />
    </template>
  </profiles-list>
</template>
