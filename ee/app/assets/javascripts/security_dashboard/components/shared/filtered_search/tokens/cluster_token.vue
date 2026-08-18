<script>
import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getClusterAgentsQuery from 'ee/security_dashboard/graphql/queries/cluster_agents.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';
import { ALL_ID as ALL_CLUSTER_VALUE } from '../constants';

export default {
  components: {
    GlFilteredSearchToken,
    GlLoadingIcon,
    SearchSuggestion,
  },
  mixins: [glListenersMixin],
  inject: ['projectFullPath'],
  transformQueryParams: (filters) => {
    return filters.map(({ value }) => value).join(',') || ALL_CLUSTER_VALUE;
  },
  transformFilters: (filters) => {
    return {
      clusterAgentId: filters.map(({ gid }) => gid),
    };
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    clusterAgents: {
      query: getClusterAgentsQuery,
      variables() {
        return {
          projectPath: this.projectFullPath,
        };
      },
      update: (data) =>
        data.project?.clusterAgents?.nodes.map((c) => ({
          value: c.name,
          text: c.name,
          gid: c.id,
        })) || [],
      error() {
        createAlert({ message: this.$options.i18n.loadingError });
      },
    },
  },
  data() {
    return {
      selected: this.value.data || [ALL_CLUSTER_VALUE],
      clusterAgents: [],
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selected,
      };
    },
    items() {
      return [
        { value: ALL_CLUSTER_VALUE, text: s__('SecurityReports|All clusters') },
        ...this.clusterAgents,
      ];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.items,
        selected: this.selected,
        maxOptionsShown: 2,
      });
    },
    isAgentDashboard() {
      return Boolean(this.agentName);
    },
    isLoading() {
      return this.$apollo.queries.clusterAgents.loading;
    },
    clusterAgentIds() {
      return this.clusterAgents.flatMap(({ value, gid }) =>
        this.selected.includes(value) ? [{ value, gid }] : [],
      );
    },
  },
  methods: {
    resetSelected() {
      this.selected = [ALL_CLUSTER_VALUE];
    },
    toggleSelected(selectedValue) {
      const allClustersSelected = selectedValue === ALL_CLUSTER_VALUE;

      if (this.selected.includes(selectedValue)) {
        this.selected = this.selected.filter((s) => s !== selectedValue);
      } else {
        this.selected = this.selected.filter((s) => s !== ALL_CLUSTER_VALUE);
        this.selected.push(selectedValue);
      }

      if (!this.selected.length || allClustersSelected) {
        this.selected = [ALL_CLUSTER_VALUE];
      }
    },
    isClusterSelected(name) {
      return this.selected.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Cluster'),
    loadingError: s__('SecurityOrchestration|Failed to load cluster agents.'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="clusterAgentIds"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelected"
    @destroy="resetSelected"
  >
    <template #view>
      <span data-testid="cluster-token-placeholder">{{ toggleText }}</span>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoading" size="sm" />
      <search-suggestion
        v-for="cluster in items"
        v-else
        :key="cluster.value"
        :value="cluster.value"
        :text="cluster.text"
        :selected="isClusterSelected(cluster.value)"
        :data-testid="`suggestion-${cluster.value}`"
      />
    </template>
  </gl-filtered-search-token>
</template>
