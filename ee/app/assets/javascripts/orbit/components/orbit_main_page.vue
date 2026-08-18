<script>
import { defineComponent } from 'vue';
import { MountingPortal } from 'portal-vue';
import { GlButton, GlButtonGroup, GlLoadingIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { fetchOrbitSchema } from '../api/orbit_api';
import {
  ENTITY_TYPE_COLORS,
  ENTITY_TYPE_NAMES,
  TAB_GRAPH,
  TAB_TABLE,
  VIEW_2D,
  VIEW_3D,
} from '../constants';
import { toGraphId } from '../utils/graph_transform';
import { measureOrbitChromeHeight } from '../utils/dom_utils';
import { fetchCombinedGraphStats } from '../utils/graph_stats';
import { ENABLED_MEMBER_NAMESPACES_LIMIT } from '../utils/namespace_limits';
import enabledMemberNamespacesQuery from '../graphql/queries/enabled_member_namespaces.query.graphql';
import memberNamespacesQuery from '../graphql/queries/member_namespaces.query.graphql';
import GraphExplorer from './graph_explorer.vue';
import OrbitExploreEmptyState from './orbit_explore_empty_state.vue';

// gap-3 (12px) + status bar (~22px) always rendered below the map in map view
const BELOW_MAP_CHROME_PX = 34;
const MIN_MAP_HEIGHT_PX = 512;
const GROUP_NODE_TYPE = 'Group';
const EMPTY_EDGES = Object.freeze([]);
const MAP_MODE_STORAGE_KEY = 'orbit-map-mode';
const VALID_MAP_MODES = new Set([VIEW_2D, VIEW_3D]);

function readStoredMapMode() {
  const stored = localStorage.getItem(MAP_MODE_STORAGE_KEY);
  return VALID_MAP_MODES.has(stored) ? stored : VIEW_3D;
}

const getGroupNumericId = (group) => getIdFromGraphQLId(group?.id);
const isSdlcMapTopLevelGroup = (group) =>
  group?.knowledgeGraphEnabled === true &&
  Boolean(group.fullPath) &&
  Number.isFinite(getGroupNumericId(group));

const VIEW_ITEMS = Object.freeze([
  { value: TAB_GRAPH, icon: 'earth', label: s__('Orbit|Map'), testid: 'view-map' },
  { value: TAB_TABLE, icon: 'table', label: s__('Orbit|Table'), testid: 'view-table' },
]);

const DIMENSION_ITEMS = Object.freeze([
  { value: VIEW_3D, label: s__('Orbit|3D'), testid: 'map-mode-3d' },
  { value: VIEW_2D, label: s__('Orbit|2D'), testid: 'map-mode-2d' },
]);

export default defineComponent({
  name: 'OrbitMainPage',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlButtonGroup,
    GlLoadingIcon,
    GraphExplorer,
    MountingPortal,
    OrbitExploreEmptyState,
  },
  mixins: [InternalEvents.mixin()],
  emptyEdges: EMPTY_EDGES,
  viewItems: VIEW_ITEMS,
  dimensionItems: DIMENSION_ITEMS,
  apollo: {
    enabledMemberGroups: {
      query: enabledMemberNamespacesQuery,
      variables: { first: ENABLED_MEMBER_NAMESPACES_LIMIT },
      update(data) {
        return data?.groups?.nodes || [];
      },
      result({ loading }) {
        if (!loading) this.enabledMemberGroupsLoaded = true;
      },
      error(err) {
        this.enabledMemberGroupsLoaded = true;
        createAlert({
          message: err.message || s__('Orbit|Failed to load groups.'),
        });
      },
    },
    memberGroups: {
      query: memberNamespacesQuery,
      variables: { first: 25 },
      skip() {
        return !this.enabledMemberGroupsLoaded || this.hasEnabledGroups;
      },
      update(data) {
        return data?.groups?.nodes || [];
      },
      error(err) {
        createAlert({
          message: err.message || s__('Orbit|Failed to load groups.'),
        });
      },
    },
  },
  data() {
    const params = new URLSearchParams(window.location.search);
    const entity = params.get('entity');
    return {
      enabledMemberGroups: [],
      enabledMemberGroupsLoaded: false,
      memberGroups: [],
      schema: null,
      activeTypeFilters: new Set(),
      advancedOpen: false,
      filterOpen: false,
      view: TAB_GRAPH,
      mapMode: readStoredMapMode(),
      instanceMapRequest: entity ? { entityType: entity, filters: {} } : null,
      displayedTypeCounts: {},
      indexedGraphStats: null,
      graphLoading: false,
      orbitChromeHeight: 0,
      panelClientHeight: 0,
    };
  },
  computed: {
    // Explicit height for the map canvas so it stays constant regardless of
    // whether the connect block is open. Falls back to CSS (min-height: 32rem)
    // until the chrome has been measured.
    orbitMapStyle() {
      if (!this.orbitChromeHeight || !this.panelClientHeight) return {};
      // Use the measured panel height (the scrollable content container) minus the
      // orbit chrome above the map. CSS custom properties are reset to 0 inside the
      // panel so we can't use var(--top-bar-height) here.
      const h = Math.max(MIN_MAP_HEIGHT_PX, this.panelClientHeight - this.orbitChromeHeight);
      return { height: `${h}px`, minHeight: '32rem', flex: 'none' };
    },
    enabledGroupsLoading() {
      return this.$apollo.queries.enabledMemberGroups.loading;
    },
    memberGroupsLoading() {
      return this.$apollo.queries.memberGroups.loading;
    },
    loading() {
      return (
        this.enabledGroupsLoading ||
        (!this.enabledMemberGroupsLoaded && !this.hasEnabledGroups) ||
        (!this.hasEnabledGroups && this.memberGroupsLoading)
      );
    },
    hasEnabledGroups() {
      return this.enabledMemberGroups.length > 0;
    },
    sdlcMapTopLevelGroups() {
      return this.enabledMemberGroups
        .slice(0, ENABLED_MEMBER_NAMESPACES_LIMIT)
        .filter(isSdlcMapTopLevelGroup);
    },
    initialGroupNodes() {
      return this.sdlcMapTopLevelGroups.map((g) => {
        const numericId = getGroupNumericId(g);
        return {
          id: toGraphId(GROUP_NODE_TYPE, numericId),
          type: 'group',
          label: g.name,
          domain: 'project',
          color: ENTITY_TYPE_COLORS.group,
          entityName: ENTITY_TYPE_NAMES.group,
          avatarUrl: g.avatarUrl,
          knowledgeGraphEnabled: g.knowledgeGraphEnabled,
          properties: {
            id: numericId,
            name: g.name,
            full_name: g.fullName,
            full_path: g.fullPath,
            knowledge_graph_enabled: g.knowledgeGraphEnabled,
          },
        };
      });
    },
    isMapView() {
      return this.view === TAB_GRAPH;
    },
    enabledNamespacePaths() {
      return this.sdlcMapTopLevelGroups.map((group) => group.fullPath);
    },
    displayedNodeCount() {
      return Object.values(this.displayedTypeCounts).reduce((total, count) => {
        const value = Number(count);
        return Number.isFinite(value) ? total + value : total;
      }, 0);
    },
    indexCountLabel() {
      if (!this.indexedGraphStats) return '';

      const total = this.indexedGraphStats.getTotalIndexedNodes();
      if (!total) return '';

      const returned = Math.min(this.displayedNodeCount, total);
      return sprintf(s__('Orbit|Showing %{returned} of %{total} indexed nodes.'), {
        returned: returned.toLocaleString(),
        total: total.toLocaleString(),
      });
    },
  },
  watch: {
    enabledMemberGroups: {
      immediate: true,
      handler() {
        this.loadIndexedTotals();
      },
    },
    mapMode(newMode) {
      localStorage.setItem(MAP_MODE_STORAGE_KEY, newMode);
    },
  },
  async mounted() {
    this.onResize = () => this.measureChrome();
    window.addEventListener('resize', this.onResize);
    this.$nextTick(() => this.measureChrome());
    await this.loadSharedSchema();
  },
  beforeUnmount() {
    window.removeEventListener('resize', this.onResize);
  },
  methods: {
    measureChrome() {
      const orbitApp = this.$el?.closest('.orbit-app');
      if (!orbitApp || !this.$el) return;

      const panel =
        this.$el.closest('.panel-content-inner') || this.$el.closest('[class*="content-inner"]');
      this.panelClientHeight = panel ? panel.clientHeight : window.innerHeight;

      const chromeWrapper = orbitApp.querySelector('[data-testid="orbit-chrome-wrapper"]');
      this.orbitChromeHeight = measureOrbitChromeHeight(
        orbitApp,
        chromeWrapper,
        BELOW_MAP_CHROME_PX,
      );
    },
    toggleAdvanced() {
      this.advancedOpen = !this.advancedOpen;
      if (this.advancedOpen) this.filterOpen = false;
    },
    toggleFilter() {
      this.filterOpen = !this.filterOpen;
      if (this.filterOpen) this.advancedOpen = false;
    },
    onTypeFilterChange(filters) {
      this.activeTypeFilters = filters;
    },
    async loadSharedSchema() {
      try {
        const { data } = await fetchOrbitSchema({ expand: '*' });
        this.schema = data;
      } catch {
        // Schema is non-critical: child explorer falls back to defaults.
      }
    },
    async loadIndexedTotals() {
      if (!this.enabledNamespacePaths.length) {
        this.indexedGraphStats = null;
        return;
      }

      this.indexedGraphStats = await fetchCombinedGraphStats(this.enabledNamespacePaths);
    },
    onNodeCountsChange(counts) {
      this.displayedTypeCounts = counts;
    },
    selectView(value) {
      if (this.view === value) return;
      this.trackEvent('click_orbit_switch_view', { label: value });
      this.view = value;
    },
    selectMapMode(value) {
      if (this.mapMode === value) return;
      this.trackEvent('click_orbit_switch_map_mode', { label: value });
      this.mapMode = value;
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-min-h-0 gl-flex-1 gl-flex-col gl-gap-5" data-testid="orbit-main-page">
    <gl-loading-icon v-if="loading" size="lg" class="gl-mt-11" />

    <orbit-explore-empty-state v-else-if="!hasEnabledGroups" :available-groups="memberGroups" />

    <template v-else>
      <mounting-portal mount-to="#orbit-tabs-actions" append>
        <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-3" data-testid="explorer-toolbar">
          <gl-loading-icon v-if="graphLoading" size="sm" inline />
          <gl-button
            size="small"
            category="tertiary"
            icon="search-results"
            data-testid="toggle-advanced"
            @click="toggleAdvanced"
          >
            <span class="gl-sr-only @sm/panel:gl-not-sr-only">{{ s__('Orbit|Query') }}</span>
          </gl-button>
          <gl-button
            size="small"
            category="tertiary"
            icon="filter"
            data-testid="toggle-filter"
            @click="toggleFilter"
          >
            <span class="gl-sr-only @sm/panel:gl-not-sr-only">{{ s__('Orbit|Filter') }}</span>
          </gl-button>
          <gl-button-group v-if="isMapView">
            <gl-button
              v-for="item in $options.dimensionItems"
              :key="item.value"
              size="small"
              :selected="mapMode === item.value"
              :data-testid="item.testid"
              @click="selectMapMode(item.value)"
            >
              {{ item.label }}
            </gl-button>
          </gl-button-group>
          <gl-button-group>
            <gl-button
              v-for="item in $options.viewItems"
              :key="item.value"
              size="small"
              :icon="item.icon"
              :selected="view === item.value"
              :data-testid="item.testid"
              @click="selectView(item.value)"
            >
              <span class="gl-sr-only @sm/panel:gl-not-sr-only">{{ item.label }}</span>
            </gl-button>
          </gl-button-group>
        </div>
      </mounting-portal>

      <div class="orbit-main-page-content gl-flex gl-min-h-0 gl-flex-1 gl-flex-col gl-gap-3">
        <graph-explorer
          class="orbit-main-graph"
          :style="orbitMapStyle"
          data-testid="panel-map"
          :initial-nodes="initialGroupNodes"
          :initial-edges="$options.emptyEdges"
          :schema="schema"
          :active-type-filters="activeTypeFilters"
          :instance-map-request="instanceMapRequest"
          :advanced-open="advancedOpen"
          :filter-open="filterOpen"
          :view="view"
          :map-mode="mapMode"
          @update-active-type-filters="onTypeFilterChange"
          @node-counts-change="onNodeCountsChange"
          @loading-change="graphLoading = $event"
          @close-filter="filterOpen = false"
          @close-query="advancedOpen = false"
        />

        <div
          v-if="indexCountLabel || isMapView"
          class="gl-ml-3 gl-flex gl-flex-wrap gl-gap-3 gl-text-sm gl-text-subtle"
        >
          <span v-if="indexCountLabel" data-testid="orbit-index-count">
            {{ indexCountLabel }}
          </span>
          <span v-if="isMapView" data-testid="graph-interaction-hint">
            {{ s__('Orbit|Click to select. Double-click to expand. Drag to move.') }}
          </span>
        </div>
      </div>
    </template>
  </div>
</template>
