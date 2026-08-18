<script>
import { defineComponent } from 'vue';
import { createAlert } from '~/alert';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { s__ } from '~/locale';
import { fetchOrbitSchema } from '../api/orbit_api';
import { fetchCombinedGraphStats } from '../utils/graph_stats';
import { ENABLED_MEMBER_NAMESPACES_LIMIT } from '../utils/namespace_limits';
import enabledMemberNamespacesQuery from '../graphql/queries/enabled_member_namespaces.query.graphql';
import SchemaDataTab from './schema_data_tab.vue';

export default defineComponent({
  name: 'OrbitSchemaPage',
  compatConfig: { MODE: 3 },
  components: { SchemaDataTab },
  apollo: {
    enabledMemberGroups: {
      query: enabledMemberNamespacesQuery,
      variables: { first: ENABLED_MEMBER_NAMESPACES_LIMIT },
      update(data) {
        return data?.groups?.nodes || [];
      },
    },
  },
  data() {
    return {
      schema: null,
      enabledMemberGroups: [],
      graphStats: null,
    };
  },
  computed: {
    limitedEnabledMemberGroups() {
      return this.enabledMemberGroups.slice(0, ENABLED_MEMBER_NAMESPACES_LIMIT);
    },
    enabledNamespacePaths() {
      return this.limitedEnabledMemberGroups.map((group) => group.fullPath).filter(Boolean);
    },
    graphStatsByType() {
      return this.graphStats?.getEntityCounts() ?? null;
    },
  },
  watch: {
    enabledMemberGroups: {
      handler() {
        this.loadGraphStats();
      },
      immediate: true,
    },
  },
  async mounted() {
    try {
      const sr = await fetchOrbitSchema({ expand: '*' });
      this.schema = sr.data;
    } catch (error) {
      Sentry.captureException(error);
      createAlert({ message: s__('Orbit|Unable to load Orbit schema. Please try again.') });
    }
  },
  methods: {
    onShowInstances({ entityType } = {}) {
      this.$router.push({
        name: 'explore',
        query: { panel: 'map', ...(entityType ? { entity: entityType } : {}) },
      });
    },
    async loadGraphStats() {
      if (!this.enabledNamespacePaths.length) {
        this.graphStats = null;
        return;
      }

      this.graphStats = await fetchCombinedGraphStats(this.enabledNamespacePaths);
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-min-h-0 gl-flex-1 gl-flex-col gl-pt-3" data-testid="orbit-schema-page">
    <schema-data-tab
      :schema="schema"
      :graph-stats="graphStatsByType"
      :initial-entity="$route.query.entity"
      @show-instances="onShowInstances"
    />
  </div>
</template>
