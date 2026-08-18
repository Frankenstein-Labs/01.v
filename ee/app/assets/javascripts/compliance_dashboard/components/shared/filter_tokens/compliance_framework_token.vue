<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK } from '../../../constants';
import FrameworkBadge from '../framework_badge.vue';

export default {
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
    FrameworkBadge,
  },
  mixins: [glListenersMixin],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      complianceFrameworks: [],
      loading: true,
    };
  },
  computed: {
    frameworkSuggestions() {
      if (this.config.includeNoFramework) {
        return [FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK, ...this.complianceFrameworks];
      }
      return this.complianceFrameworks;
    },
  },
  mounted() {
    if (this.value?.data) {
      this.fetchFrameworks();
    }
  },
  methods: {
    fetchComplianceFrameworks() {
      if (this.config.frameworks) {
        return Promise.resolve(this.config.frameworks);
      }
      return this.$apollo
        .query({
          query: getComplianceFrameworkQuery,
          variables: {
            fullPath: this.config.groupPath,
          },
        })
        .then(({ data }) => data.namespace?.complianceFrameworks?.nodes || []);
    },
    fetchFrameworks() {
      this.loading = true;
      this.fetchComplianceFrameworks()
        .then((frameworks) => {
          this.complianceFrameworks = frameworks;
        })
        .catch((error) => {
          Sentry.captureException(error);
          createAlert({
            message: s__('ComplianceReport|There was a problem fetching compliance frameworks.'),
          });
        })
        .finally(() => {
          this.loading = false;
        });
    },
    getActiveFramework(frameworks, data) {
      if (data) {
        if (data === FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.id) {
          return FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK;
        }

        if (frameworks.length) {
          return frameworks.find((framework) => this.getValue(framework) === data);
        }
      }
      return undefined;
    },
    getValue(framework) {
      return framework.id;
    },
    displayValue(framework) {
      return framework.name;
    },
  },
  FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK,
};
</script>

<template>
  <base-token
    :config="config"
    :value="value"
    :active="active"
    :suggestions-loading="loading"
    :suggestions="frameworkSuggestions"
    :get-active-token-value="getActiveFramework"
    :value-identifier="getValue"
    v-bind="$attrs"
    search-by="name"
    @fetch-suggestions="fetchFrameworks"
    v-on="glListeners()"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      <template v-if="activeTokenValue">
        <template v-if="activeTokenValue.id === $options.FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.id">
          {{ displayValue(activeTokenValue) }}
        </template>
        <template v-else>
          <framework-badge :framework="activeTokenValue" popover-mode="hidden" />
        </template>
      </template>
      <template v-else>
        {{ inputValue }}
      </template>
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="framework in suggestions"
        :key="framework.id"
        :value="getValue(framework)"
      >
        <framework-badge
          v-if="framework.id !== $options.FRAMEWORKS_FILTER_VALUE_NO_FRAMEWORK.id"
          :framework="framework"
          popover-mode="hidden"
        />
        <template v-else>{{ framework.name }}</template>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
