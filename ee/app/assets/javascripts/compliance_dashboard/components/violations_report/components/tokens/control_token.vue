<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { humanize } from '~/lib/utils/text_utility';
import complianceRequirementControlsQuery from 'ee/compliance_dashboard/graphql/compliance_requirement_controls.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import complianceFrameworksWithControlsQuery from '../../graphql/queries/compliance_frameworks_with_controls.query.graphql';

export default {
  name: 'ControlToken',
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
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
      controlDefinitions: [],
      shouldFetch: false,
      frameworks: [],
    };
  },
  apollo: {
    controlDefinitions: {
      query: complianceRequirementControlsQuery,
      update: (data) => data.complianceRequirementControls.controlExpressions || [],
    },
    frameworks: {
      query: complianceFrameworksWithControlsQuery,
      skip() {
        return !this.shouldFetch;
      },
      variables() {
        return {
          fullPath: this.config.groupPath,
        };
      },
      update(data) {
        const frameworkNodes = data.namespace?.complianceFrameworks?.nodes || [];
        const controlsWithFramework = [];

        frameworkNodes.forEach((framework) => {
          framework.complianceRequirements?.nodes?.forEach((requirement) => {
            requirement.complianceRequirementsControls?.nodes?.forEach((control) => {
              controlsWithFramework.push({
                ...control,
                frameworkName: framework.name,
                frameworkColor: framework.color,
                requirementName: requirement.name,
              });
            });
          });
        });

        return controlsWithFramework;
      },
      error(error) {
        Sentry.captureException(error);
        createAlert({
          message: s__('ComplianceReport|There was a problem fetching compliance controls.'),
        });
      },
    },
  },
  computed: {
    controls() {
      return this.frameworks || [];
    },
    loading() {
      return this.$apollo.queries.frameworks?.loading ?? false;
    },
  },
  methods: {
    fetchControls() {
      this.shouldFetch = true;
    },
    getActiveControl(controls, data) {
      if (!data) {
        return undefined;
      }
      return controls.find((control) => this.getValue(control) === data);
    },
    getValue(control) {
      return control.id;
    },
    getControlDisplayName(controlName) {
      if (!controlName) return '';

      // Try to find the control definition with proper display name
      const definition = this.controlDefinitions.find((def) => def.id === controlName);
      if (definition?.name) {
        return definition.name;
      }

      // Fallback: format the control name
      return humanize(controlName);
    },
    displayValue(control) {
      if (!control) return '';
      // Use externalControlName if available
      if (control.externalControlName) {
        return control.externalControlName;
      }
      return this.getControlDisplayName(control.name);
    },
    displayValueWithContext(control) {
      if (!control) return '';
      const displayName = control.externalControlName || this.getControlDisplayName(control.name);
      return `${displayName} (${control.frameworkName})`;
    },
  },
};
</script>

<template>
  <base-token
    :config="config"
    :value="value"
    :active="active"
    :suggestions-loading="loading"
    :suggestions="controls"
    :get-active-token-value="getActiveControl"
    :value-identifier="getValue"
    v-bind="$attrs"
    search-by="name"
    @fetch-suggestions="fetchControls"
    v-on="glListeners()"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      {{ activeTokenValue ? displayValue(activeTokenValue) : inputValue }}
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="control in suggestions"
        :key="control.id"
        :value="getValue(control)"
      >
        {{ displayValueWithContext(control) }}
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
