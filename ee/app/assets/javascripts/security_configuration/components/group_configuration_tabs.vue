<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import GroupScannersOverview from './scan_profiles/group_scanners_overview.vue';
import ConfigureAttributes from './security_attributes/configure_attributes.vue';

export default {
  name: 'GroupConfigurationTabs',
  components: {
    GlTabs,
    GlTab,
    PageHeading,
    GroupScannersOverview,
    ConfigureAttributes,
  },
  inject: ['canManageAttributes', 'canReadScanProfiles'],
};
</script>
<template>
  <div>
    <page-heading :heading="s__('SecurityConfiguration|Security configuration')" />
    <gl-tabs sync-active-tab-with-query-params query-param-name="tab">
      <gl-tab v-if="canReadScanProfiles" query-param-value="scanners">
        <template #title>
          {{ s__('SecurityConfiguration|Scanners') }}
        </template>

        <group-scanners-overview />
      </gl-tab>
      <gl-tab v-if="canManageAttributes" query-param-value="attributes">
        <template #title>
          {{ s__('SecurityAttributes|Security attributes') }}
        </template>
        <p class="gl-my-5">
          {{
            s__(
              'SecurityAttributes|Use security attributes to categorize projects by business context, security needs, and more. Categories are shared across your groups, enabling consistent and scalable classification of assets. These attributes can help prioritize security efforts, filter dashboards, and apply consistent governance across projects.',
            )
          }}
        </p>
        <configure-attributes />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
