<script>
import { defineComponent } from 'vue';
import {
  GlButton,
  GlCard,
  GlCollapsibleListbox,
  GlIcon,
  GlLoadingIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __, n__, s__, sprintf } from '~/locale';
import { vuerouteDashboardOrbitPath } from 'ee/lib/utils/path_helpers/dashboard';
import { fetchGraphStatus } from '../api/orbit_api';
import namespaceDescendantsQuery from '../graphql/queries/namespace_descendants.query.graphql';
import {
  ENTITY_TYPE_ICONS,
  ENTITY_TYPE_COLORS,
  ENTITY_TYPE_NAMES,
  DEFAULT_ENTITY_COLOR,
  DOMAIN_ORDER,
  DOMAIN_LABELS,
} from '../constants';

const SEARCH_DEBOUNCE_MS = 500;
const STATUS_POLLING_INTERVAL_MS = 20000;
const ALL_SCOPE = 'all';

export default defineComponent({
  name: 'NamespaceIndexCard',
  compatConfig: { MODE: 3 },
  components: {
    GlButton,
    GlCard,
    GlCollapsibleListbox,
    GlIcon,
    GlLoadingIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    namespace: {
      type: Object,
      required: true,
    },
  },
  apollo: {
    namespaceChildren: {
      query: namespaceDescendantsQuery,
      variables() {
        return { fullPath: this.namespace.fullPath, search: this.searchTerm || null };
      },
      update(data) {
        return data?.group || {};
      },
      skip() {
        return !this.namespace?.fullPath;
      },
    },
  },
  data() {
    return {
      graphStatus: null,
      statusLoading: true,
      namespaceChildren: {},
      selectedFilter: ALL_SCOPE,
      selectedFilterName: '',
      searchTerm: '',
      contentExpanded: true,
      statusPollingIntervalId: null,
    };
  },
  computed: {
    hasFilter() {
      return this.selectedFilter !== ALL_SCOPE;
    },
    lastIndexedDisplay() {
      const timestamp =
        this.graphStatus?.indexing?.last_completed_at ||
        this.graphStatus?.indexing?.last_started_at;
      if (!timestamp) {
        return `${s__('Orbit|Last indexed:')} ${s__('Orbit|Pending')}`;
      }

      const date = new Date(timestamp);
      if (Number.isNaN(date.getTime())) {
        return `${s__('Orbit|Last indexed:')} ${s__('Orbit|Pending')}`;
      }

      const formatted = date
        .toISOString()
        .replace('T', ' ')
        .replace(/\.\d+Z$/, __(' UTC'));
      return `${s__('Orbit|Last indexed:')} ${formatted}`;
    },
    entityCount() {
      return (this.graphStatus?.domains || []).reduce(
        (sum, domain) => sum + domain.items.reduce((s, item) => s + (item.count || 0), 0),
        0,
      );
    },
    projectIndexDisplay() {
      const projects = this.graphStatus?.projects;
      if (!projects) return null;

      const indexed = projects.indexed || 0;
      const total = projects.total_known || 0;
      if (total > 0) {
        return sprintf(
          s__('Orbit|%{indexed} of %{total} projects indexed'),
          { indexed: indexed.toLocaleString(), total: total.toLocaleString() },
          false,
        );
      }
      if (indexed > 0) {
        return sprintf(
          n__('Orbit|%{indexed} project indexed', 'Orbit|%{indexed} projects indexed', indexed),
          { indexed: indexed.toLocaleString() },
          false,
        );
      }

      return null;
    },
    domainGroups() {
      const domains = this.graphStatus?.domains || [];
      const domainMap = {};
      for (const domain of domains) {
        if (domain.items.length > 0) {
          domainMap[domain.name] = domain;
        }
      }
      return DOMAIN_ORDER.filter((name) => domainMap[name]).map((name) => domainMap[name]);
    },
    filterItems() {
      const groups = (this.namespaceChildren?.descendantGroups?.nodes || []).map((g) => ({
        value: g.fullPath,
        text: g.name,
      }));
      const projects = (this.namespaceChildren?.projects?.nodes || []).map((p) => ({
        value: p.fullPath,
        text: p.name,
      }));
      return [
        ...(groups.length ? [{ text: s__('Orbit|Groups'), options: groups }] : []),
        ...(projects.length ? [{ text: s__('Orbit|Projects'), options: projects }] : []),
      ];
    },
    filterToggleText() {
      if (this.selectedFilter === ALL_SCOPE) {
        return s__('Orbit|All groups and projects');
      }
      return this.selectedFilterName || this.selectedFilter;
    },
    exploreDataHref() {
      const base = vuerouteDashboardOrbitPath({ vueroute: 'explore' });
      const params = new URLSearchParams({ panel: 'map', group: this.namespace.fullPath });
      if (this.hasFilter) {
        params.set('group', this.selectedFilter);
      }
      return `${base}?${params}`;
    },
  },
  watch: {
    selectedFilter() {
      this.loadStatus();
    },
  },
  created() {
    this.debouncedSearch = debounce((term) => {
      this.searchTerm = term;
    }, SEARCH_DEBOUNCE_MS);
  },
  mounted() {
    this.loadStatus();
    this.statusPollingIntervalId = setInterval(() => {
      this.loadStatus({ silent: true });
    }, STATUS_POLLING_INTERVAL_MS);
  },
  beforeUnmount() {
    this.debouncedSearch?.cancel();
    clearInterval(this.statusPollingIntervalId);
    this.statusAbortController?.abort();
  },
  methods: {
    async loadStatus({ silent = false } = {}) {
      const path =
        this.selectedFilter === ALL_SCOPE ? this.namespace.fullPath : this.selectedFilter;
      if (!silent) {
        this.statusLoading = true;
      }
      this.statusAbortController?.abort();
      const controller = new AbortController();
      this.statusAbortController = controller;
      try {
        const { data } = await fetchGraphStatus(path, { signal: controller.signal });
        this.graphStatus = data;
      } catch (error) {
        if (axios.isCancel(error) || error.code === 'ERR_CANCELED') {
          return;
        }
        Sentry.captureException(error);
        if (!silent && this.statusAbortController === controller) {
          createAlert({ message: s__('Orbit|Unable to load index status. Please try again.') });
          this.graphStatus = null;
        }
      } finally {
        if (!silent && this.statusAbortController === controller) {
          this.statusLoading = false;
        }
      }
    },
    entityIcon(name) {
      return ENTITY_TYPE_ICONS[name.toLowerCase()];
    },
    entityColor(name) {
      return ENTITY_TYPE_COLORS[name.toLowerCase()] || DEFAULT_ENTITY_COLOR;
    },
    entityDisplayName(name) {
      return ENTITY_TYPE_NAMES[name.toLowerCase()] || name;
    },
    domainLabel(name) {
      return DOMAIN_LABELS[name] || name;
    },
    formatCount(item) {
      return (item.count || 0).toLocaleString();
    },
    exploreHref(entityName) {
      const base = vuerouteDashboardOrbitPath({ vueroute: 'explore' });
      const params = new URLSearchParams({
        panel: 'map',
        entity: entityName,
        group: this.namespace.fullPath,
      });
      return `${base}?${params}`;
    },
    onFilterSelect(value) {
      if (!value || value === ALL_SCOPE) {
        this.onFilterClear();
        return;
      }

      const allItems = [
        ...(this.namespaceChildren?.descendantGroups?.nodes || []),
        ...(this.namespaceChildren?.projects?.nodes || []),
      ];
      const match = allItems.find((item) => item.fullPath === value);
      this.selectedFilterName = match?.name || value;
      this.selectedFilter = value;
    },
    onFilterClear() {
      this.selectedFilterName = '';
      this.selectedFilter = ALL_SCOPE;
    },
    onFilterSearch(term) {
      this.debouncedSearch(term);
    },
  },
});
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-4">
    <!-- Indexed content card -->
    <gl-card
      :body-class="contentExpanded ? 'gl-block' : 'gl-hidden'"
      :header-class="contentExpanded ? '' : 'gl-pb-2'"
    >
      <template #header>
        <div class="gl-flex gl-flex-1 gl-items-center gl-justify-between">
          <div class="gl-flex gl-flex-wrap gl-items-center gl-gap-4">
            <span class="gl-font-bold">{{ s__('Orbit|Indexed content') }}</span>
            <template v-if="!statusLoading">
              <span class="gl-text-sm gl-text-subtle">
                {{ entityCount.toLocaleString() }} {{ s__('Orbit|entities') }}
              </span>
              <span v-if="projectIndexDisplay" class="gl-text-sm gl-text-subtle">
                {{ projectIndexDisplay }}
              </span>
            </template>
          </div>
          <gl-button
            category="tertiary"
            size="small"
            :icon="contentExpanded ? 'chevron-lg-up' : 'chevron-lg-down'"
            :aria-label="s__('Orbit|Toggle indexed content')"
            @click="contentExpanded = !contentExpanded"
          />
        </div>
      </template>

      <template v-if="contentExpanded">
        <gl-loading-icon v-if="statusLoading" size="lg" />

        <template v-else>
          <!-- Filter + scoped stats -->
          <div class="gl-mb-4 gl-flex gl-items-center gl-gap-5">
            <gl-collapsible-listbox
              v-if="domainGroups.length"
              :selected="selectedFilter"
              :items="filterItems"
              :toggle-text="filterToggleText"
              :header-text="s__('Orbit|Select scope')"
              :reset-button-label="s__('Orbit|Clear')"
              :searching="$apollo.queries.namespaceChildren.loading"
              searchable
              @search="onFilterSearch"
              @select="onFilterSelect"
              @reset="onFilterClear"
            />
            <div class="gl-flex gl-flex-wrap gl-gap-5 gl-text-sm gl-text-subtle">
              <template v-if="hasFilter">
                <span>{{ lastIndexedDisplay }}</span>
                <span>{{ entityCount.toLocaleString() }} {{ s__('Orbit|entities') }}</span>
                <span v-if="projectIndexDisplay">{{ projectIndexDisplay }}</span>
              </template>
              <a :href="exploreDataHref" class="gl-ml-auto gl-text-sm">
                {{ s__('Orbit|Explore data') }}
              </a>
            </div>
          </div>

          <div v-for="domain in domainGroups" :key="domain.name" class="gl-mb-5">
            <p class="gl-mb-2 gl-mt-0 gl-text-xs gl-font-bold gl-text-subtle">
              {{ domainLabel(domain.name) }}
            </p>
            <div class="gl-flex gl-flex-wrap gl-gap-3">
              <a
                v-for="item in domain.items"
                :key="item.name"
                v-gl-tooltip="s__('Orbit|Open as query')"
                :href="exploreHref(item.name)"
                class="gl-border gl-flex gl-items-center gl-gap-4 gl-rounded-base gl-px-2 gl-py-1 gl-text-sm gl-text-default gl-no-underline hover:gl-bg-subtle hover:gl-text-default hover:gl-no-underline"
              >
                <span class="gl-flex gl-items-center gl-gap-2">
                  <gl-icon
                    v-if="entityIcon(item.name)"
                    :name="entityIcon(item.name)"
                    :size="12"
                    :style="{ color: entityColor(item.name) }"
                  />
                  <span
                    v-else
                    class="gl-inline-block gl-h-2 gl-w-2 gl-flex-shrink-0 gl-rounded-full"
                    :style="{ backgroundColor: entityColor(item.name) }"
                  ></span>
                  {{ entityDisplayName(item.name) }}
                </span>
                <gl-loading-icon v-if="item.status === 'pending'" size="sm" inline />
                <span v-else class="gl-tabular-nums gl-text-subtle">{{ formatCount(item) }}</span>
              </a>
            </div>
          </div>

          <p v-if="!domainGroups.length" class="gl-mb-0 gl-text-subtle">
            {{ s__('Orbit|No indexing data available yet.') }}
          </p>
        </template>
      </template>
    </gl-card>
  </div>
</template>
