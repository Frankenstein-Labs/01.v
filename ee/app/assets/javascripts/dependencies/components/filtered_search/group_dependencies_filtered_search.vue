<script>
import { __ } from '~/locale';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import MalwareToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/malware_token.vue';
import LicenseToken from './tokens/license_token.vue';
import ProjectToken from './tokens/project_token.vue';
import ComponentToken from './tokens/component_token.vue';
import VersionToken from './tokens/version_token.vue';
import DependenciesFilteredSearch from './dependencies_filtered_search.vue';

export default {
  components: {
    DependenciesFilteredSearch,
  },
  mixins: [glFeatureFlagsMixin()],
  computed: {
    tokens() {
      const tokens = [
        {
          type: 'licenses',
          title: __('License'),
          multiSelect: true,
          unique: true,
          token: LicenseToken,
          operators: OPERATORS_IS,
        },
        {
          type: 'project_ids',
          title: __('Project'),
          multiSelect: true,
          unique: true,
          token: ProjectToken,
          operators: OPERATORS_IS,
        },
        {
          type: 'component_names',
          title: __('Component'),
          multiSelect: true,
          unique: true,
          token: ComponentToken,
          operators: OPERATORS_IS,
        },
        {
          type: 'component_versions',
          title: __('Version'),
          multiSelect: true,
          unique: true,
          token: VersionToken,
          operators: OPERATORS_IS_NOT,
        },
      ];

      if (this.glFeatures.maliciousPackageDetection) {
        tokens.push({
          type: 'malware',
          title: MalwareToken.i18n.label,
          multiSelect: false,
          unique: true,
          token: MalwareToken,
          operators: OPERATORS_IS,
        });
      }

      return tokens;
    },
  },
  filteredSearchId: 'group-level-filtered-search',
};
</script>

<template>
  <div>
    <dependencies-filtered-search
      :tokens="tokens"
      :filtered-search-id="$options.filteredSearchId"
    />
  </div>
</template>
