<script>
import { GlButton, GlCollapsibleListbox, GlIcon, GlTruncate } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { createAlert } from '~/alert';
import { n__, s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { TYPENAME_SBOM_COMPONENT_VERSION } from 'ee/graphql_shared/constants';
import getDependencyTrackedRefs from '../graphql/dependency_tracked_refs.query.graphql';
import { SEARCH_MIN_THRESHOLD } from './constants';

const mapItemToListboxFormat = (item) => ({ ...item, value: item.id, text: item.name });

// Matches max_page_size: 20 on the dependency_tracked_refs field in
// ee/app/graphql/ee/types/project_type.rb — requesting more has no effect.
export const TRACKED_REFS_PAGE_SIZE = 20;

export default {
  name: 'DependencyRefCount',
  components: {
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    GlTruncate,
  },
  inject: ['fullPath'],
  props: {
    trackedRefsCount: {
      type: Number,
      required: true,
    },
    componentVersionId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      loading: true,
      trackedRefs: [],
      searchTerm: '',
    };
  },
  computed: {
    refsText() {
      return n__('Dependencies|%d ref', 'Dependencies|%d refs', this.trackedRefsCount);
    },
    searchEnabled() {
      return this.loading || this.trackedRefsCount > SEARCH_MIN_THRESHOLD;
    },
  },
  created() {
    this.search = debounce((searchTerm) => {
      this.searchTerm = searchTerm;
      this.fetchData();
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  beforeDestroy() {
    this.search.cancel();
  },
  methods: {
    onHide() {
      this.search.cancel();
      this.searchTerm = '';
    },
    onShown() {
      this.fetchData();
    },
    async fetchData() {
      this.loading = true;

      try {
        const { data } = await this.$apollo.query({
          query: getDependencyTrackedRefs,
          variables: {
            fullPath: this.fullPath,
            componentVersionId: convertToGraphQLId(
              TYPENAME_SBOM_COMPONENT_VERSION,
              this.componentVersionId,
            ),
            search: this.searchTerm,
            first: TRACKED_REFS_PAGE_SIZE,
          },
        });

        const nodes = data.project?.dependencyTrackedRefs?.nodes ?? [];

        this.trackedRefs = nodes.map(mapItemToListboxFormat);
      } catch (error) {
        createAlert({
          message: s__('Dependencies|There was a problem fetching the refs for this dependency.'),
          captureError: true,
          error,
        });
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :header-text="refsText"
    :items="trackedRefs"
    :searching="loading"
    :searchable="searchEnabled"
    @hidden="onHide"
    @search="search"
    @shown="onShown"
  >
    <template #toggle>
      <gl-button variant="link" category="tertiary" data-testid="ref-count">
        <span class="@md/panel:gl-hidden">{{ trackedRefsCount }}</span>
        <span class="gl-hidden @md/panel:gl-inline-flex" data-testid="ref-count-text">{{
          refsText
        }}</span>
      </gl-button>
    </template>
    <template #list-item="{ item }">
      <span class="gl-flex gl-items-center gl-gap-3">
        <gl-icon :name="item.refType.toLowerCase()" :size="16" />
        <gl-truncate position="end" :text="item.name" with-tooltip class="gl-min-w-0" />
      </span>
    </template>
  </gl-collapsible-listbox>
</template>
