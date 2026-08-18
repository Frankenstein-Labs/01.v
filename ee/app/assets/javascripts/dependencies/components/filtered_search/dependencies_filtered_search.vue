<script>
import { GlFilteredSearch } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions } from 'vuex';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { NAMESPACE_PROJECT } from '../../constants';

export default {
  components: {
    GlFilteredSearch,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['namespaceType'],
  props: {
    filteredSearchId: {
      type: String,
      required: true,
    },
    tokens: {
      type: Array,
      required: true,
    },
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  methods: {
    ...mapActions([
      'setSearchFilterParameters',
      'fetchDependencies',
      'fetchDependenciesViaGraphQL',
    ]),
    fetchDependenciesWithFeatureFlag() {
      if (this.namespaceType === NAMESPACE_PROJECT) {
        this.fetchDependenciesViaGraphQL();
      } else {
        this.fetchDependencies({ page: 1 });
      }
    },
  },
  i18n: {
    searchInputPlaceholder: s__('Dependencies|Search or filter dependencies…'),
  },
};
</script>

<template>
  <gl-filtered-search
    :id="filteredSearchId"
    :value="value"
    :placeholder="$options.i18n.searchInputPlaceholder"
    :available-tokens="tokens"
    terms-as-tokens
    @input="setSearchFilterParameters"
    @submit="fetchDependenciesWithFeatureFlag"
  />
</template>
