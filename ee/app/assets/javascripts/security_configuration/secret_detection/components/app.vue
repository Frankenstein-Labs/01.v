<script>
import { GlTabs, GlTab, GlBadge, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import ProjectSecurityExclusionQuery from 'ee/security_configuration/secret_detection/graphql/project_security_exclusions.query.graphql';
import { DRAWER_MODES } from '../constants';
import EmptyState from './empty_state.vue';
import ExclusionList from './exclusion_list.vue';
import ExclusionFormDrawer from './exclusion_form_drawer.vue';

export default {
  name: 'SecretDetectionApp',
  components: {
    GlTabs,
    GlTab,
    GlBadge,
    EmptyState,
    GlLoadingIcon,
    ExclusionList,
    ExclusionFormDrawer,
  },
  inject: ['projectFullPath'],
  i18n: {
    pageHeading: s__('SecretDetection|Secret detection configuration'),
  },
  data() {
    return {
      exclusions: [],
    };
  },
  apollo: {
    exclusions: {
      query: ProjectSecurityExclusionQuery,
      variables() {
        return {
          fullPath: this.projectFullPath,
        };
      },
      update(data) {
        return data?.project?.exclusions?.nodes || [];
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.exclusions.loading;
    },
  },
  methods: {
    openDrawer(mode, item) {
      this.$refs.exclusionFormDrawer.open(mode, item);
    },
    refreshList() {
      this.$apollo.queries.exclusions.refetch();
    },
    addExclusion() {
      this.openDrawer(DRAWER_MODES.ADD);
    },
    editExclusion(item) {
      this.openDrawer(DRAWER_MODES.EDIT, item);
    },
    viewExclusion(item) {
      this.openDrawer(DRAWER_MODES.VIEW, item);
    },
  },
};
</script>

<template>
  <div>
    <h1>{{ $options.i18n.pageHeading }}</h1>
    <gl-tabs>
      <gl-tab>
        <template #title>
          <span>{{ __('Exclusions') }}</span>
          <gl-badge class="gl-tab-counter-badge" variant="neutral">{{
            exclusions.length
          }}</gl-badge>
        </template>

        <div class="gl-mt-3">
          <empty-state v-if="!isLoading && !exclusions.length" @primary-action="openDrawer" />
          <gl-loading-icon v-else-if="isLoading" size="lg" class="gl-mt-5" />
          <exclusion-list
            v-else
            :exclusions="exclusions"
            @add-exclusion="addExclusion"
            @edit-exclusion="editExclusion"
            @view-exclusion="viewExclusion"
          />
        </div>
      </gl-tab>
    </gl-tabs>

    <exclusion-form-drawer ref="exclusionFormDrawer" @updated="refreshList" />
  </div>
</template>
