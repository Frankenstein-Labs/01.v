<script>
import { defineAsyncComponent } from 'vue';
import { GlAlert, GlTabs, GlTab } from '@gitlab/ui';
import { n__ } from '~/locale';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/common/registries/list.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import upstreamsFetchMixin, {
  INITIAL_UPSTREAMS_PARAMS,
} from 'ee/packages_and_registries/virtual_registries/mixins/upstreams/fetch';

export default {
  name: 'MavenVirtualRegistriesAndUpstreamsApp',
  components: {
    GlAlert,
    GlTabs,
    GlTab,
    RegistriesList,
    CleanupPolicyStatus,
    UpstreamsList: defineAsyncComponent(
      () =>
        import('ee/packages_and_registries/virtual_registries/components/common/upstreams/list.vue'),
    ),
    UserCalloutDismisser,
  },
  mixins: [upstreamsFetchMixin],
  inject: ['fullPath'],
  data() {
    return {
      registriesCount: null,
    };
  },
  computed: {
    registriesTabCountSRText() {
      if (this.registriesCount === null) return '';

      return n__(
        'VirtualRegistry|%d registry',
        'VirtualRegistry|%d registries',
        this.registriesCount,
      );
    },
  },
  methods: {
    updateRegistriesCount(newCount) {
      this.registriesCount = newCount;
    },
    handleUpstreamDeleted() {
      this.upstreamsPageParams = INITIAL_UPSTREAMS_PARAMS;
      this.$apollo.queries.upstreams.refetch();
      this.$apollo.queries.upstreamsCount.refetch();
    },
  },
};
</script>

<template>
  <div>
    <cleanup-policy-status batch-key="MavenVirtualRegistries" />
    <user-callout-dismisser feature-name="virtual_registry_permission_change_alert">
      <template #default="{ dismiss, shouldShowCallout }">
        <gl-alert v-if="shouldShowCallout" class="gl-my-3" @dismiss="dismiss">
          {{
            s__(
              'VirtualRegistry|Direct project membership no longer grants access to the Maven virtual registry. To access the virtual registry, you must be a member of the top-level group or an administrator.',
            )
          }}
        </gl-alert>
      </template>
    </user-callout-dismisser>
    <gl-tabs content-class="gl-p-0" sync-active-tab-with-query-params>
      <gl-tab
        :title="s__('VirtualRegistry|Registries')"
        :tab-count="registriesCount"
        :tab-count-sr-text="registriesTabCountSRText"
        query-param-value="registries"
      >
        <registries-list @update-count="updateRegistriesCount" />
      </gl-tab>
      <gl-tab
        :title="s__('VirtualRegistry|Upstreams')"
        :tab-count="upstreamsCount"
        :tab-count-sr-text="upstreamsTabCountSRText"
        query-param-value="upstreams"
        lazy
      >
        <upstreams-list
          :upstreams="upstreams"
          :loading="$apollo.queries.upstreams.loading"
          :search-term="upstreamsSearchTerm"
          @submit="handleUpstreamsSearch"
          @page-change="handleUpstreamsPagination"
          @upstream-deleted="handleUpstreamDeleted"
        />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
