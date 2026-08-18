<script>
import { GlTabs, GlTab, GlButton } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/common/registries/list.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/list.vue';
import upstreamsFetchMixin from 'ee/packages_and_registries/virtual_registries/mixins/upstreams/fetch';
import { CONTAINER_REGISTRIES_INDEX, CONTAINER_UPSTREAMS_INDEX } from './routes';

export default {
  name: 'ContainerRegistriesAndUpstreams',
  components: {
    GlTabs,
    GlTab,
    GlButton,
    CleanupPolicyStatus,
    PageHeading,
    RegistriesList,
    UpstreamsList,
  },
  mixins: [upstreamsFetchMixin, glAbilitiesMixin()],
  inject: ['fullPath', 'i18n', 'maxRegistriesCount'],
  data() {
    return {
      registriesCount: null,
    };
  },
  computed: {
    pageHeadingDescription() {
      return sprintf(
        s__('VirtualRegistry|You can add up to %{count} registries per top-level group.'),
        {
          count: this.maxRegistriesCount,
        },
      );
    },
    maxRegistriesReached() {
      return this.registriesCount === this.maxRegistriesCount;
    },
    isRegistriesRoute() {
      return this.$route.name === CONTAINER_REGISTRIES_INDEX;
    },
    isUpstreamsRoute() {
      return this.$route.name === CONTAINER_UPSTREAMS_INDEX;
    },
    registriesTabAttributes() {
      return { href: this.$router.resolve({ name: CONTAINER_REGISTRIES_INDEX }).href };
    },
    upstreamsTabAttributes() {
      return { href: this.$router.resolve({ name: CONTAINER_UPSTREAMS_INDEX }).href };
    },
    registriesTabCountSRText() {
      if (this.registriesCount === null) return '';

      return n__(
        'VirtualRegistry|%d registry',
        'VirtualRegistry|%d registries',
        this.registriesCount,
      );
    },
    canCreateRegistry() {
      return this.registriesCount !== null && this.glAbilities.createVirtualRegistry;
    },
  },
  methods: {
    handleRegistriesTabClick() {
      this.$router.push({ name: CONTAINER_REGISTRIES_INDEX });
    },
    handleUpstreamsTabClick() {
      this.$router.push({ name: CONTAINER_UPSTREAMS_INDEX });
    },
    updateRegistriesCount(newCount) {
      this.registriesCount = newCount;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="i18n.registries.pageHeading">
      <template #description>
        {{ pageHeadingDescription }}
      </template>
      <template v-if="canCreateRegistry" #actions>
        <span v-if="maxRegistriesReached" role="status" aria-live="polite">{{
          s__('VirtualRegistry|Maximum number of registries reached.')
        }}</span>
        <gl-button v-else :to="{ name: 'REGISTRY_NEW' }" variant="confirm">
          {{ s__('VirtualRegistry|Create registry') }}
        </gl-button>
      </template>
    </page-heading>
    <cleanup-policy-status batch-key="ContainerVirtualRegistries" />
    <gl-tabs content-class="gl-p-0">
      <gl-tab
        :title="s__('VirtualRegistry|Registries')"
        :tab-count="registriesCount"
        :tab-count-sr-text="registriesTabCountSRText"
        :active="isRegistriesRoute"
        :title-link-attributes="registriesTabAttributes"
        @click="handleRegistriesTabClick"
      >
        <registries-list @update-count="updateRegistriesCount" />
      </gl-tab>
      <gl-tab
        :title="s__('VirtualRegistry|Upstreams')"
        :tab-count="upstreamsCount"
        :tab-count-sr-text="upstreamsTabCountSRText"
        :active="isUpstreamsRoute"
        :title-link-attributes="upstreamsTabAttributes"
        @click="handleUpstreamsTabClick"
      >
        <upstreams-list
          :upstreams="upstreams"
          :loading="$apollo.queries.upstreams.loading"
          :search-term="upstreamsSearchTerm"
          @submit="handleUpstreamsSearch"
          @page-change="handleUpstreamsPagination"
          @upstream-deleted="handleUpstreamsDeleted"
        />
      </gl-tab>
    </gl-tabs>
  </div>
</template>
