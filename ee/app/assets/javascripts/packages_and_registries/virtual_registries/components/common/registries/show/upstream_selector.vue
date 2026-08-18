<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

const PAGE_SIZE = 20;
const INITIAL_VALUE = { nodes: [], pageInfo: {} };

export default {
  name: 'UpstreamSelector',
  components: {
    GlCollapsibleListbox,
  },
  inject: ['fullPath', 'getUpstreamsSelectQuery'],
  props: {
    linkedUpstreamIds: {
      type: Array,
      required: true,
    },
  },
  emits: ['select'],
  data() {
    return {
      isLoadingMore: false,
      searchTerm: '',
      pageParams: {
        first: PAGE_SIZE,
      },
      selectedUpstream: null,
      upstreams: INITIAL_VALUE,
    };
  },
  apollo: {
    upstreams: {
      query() {
        return this.getUpstreamsSelectQuery;
      },
      variables() {
        return { groupPath: this.fullPath, upstreamName: this.searchTerm, ...this.pageParams };
      },
      update: (data) => data.group?.upstreams ?? INITIAL_VALUE,
      error(error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to fetch upstreams. Please try again.'),
          error,
          captureError: true,
        });
      },
      debounce: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
    },
  },
  computed: {
    isSearching() {
      return this.$apollo.queries.upstreams.loading && !this.isLoadingMore;
    },
    linkableUpstreams() {
      return (
        this.upstreams.nodes
          // filter out upstreams that are already linked to this virtual registry
          .filter((upstream) => {
            return this.linkedUpstreamIds.indexOf(upstream.value) === -1;
          })
      );
    },
    selectedUpstreamName() {
      return this.selectedUpstream?.text ?? s__('VirtualRegistry|Select an upstream');
    },
    selectedUpstreamId() {
      return this.selectedUpstream?.value;
    },
  },
  methods: {
    searchUpstream(searchTerm = '') {
      this.searchTerm = searchTerm;
      this.pageParams = {
        first: PAGE_SIZE,
      };
    },
    async fetchNextPage() {
      if (this.$apollo.queries.upstreams.loading || !this.upstreams.pageInfo.hasNextPage) {
        return;
      }

      this.isLoadingMore = true;
      try {
        await this.$apollo.queries.upstreams.fetchMore({
          variables: {
            first: PAGE_SIZE,
            after: this.upstreams.pageInfo.endCursor,
            upstreamName: this.searchTerm,
          },
        });
      } catch (error) {
        captureException({ error, component: this.$options.name });
      } finally {
        this.isLoadingMore = false;
      }
    },
    handleSelect(upstreamId) {
      this.selectedUpstream = this.linkableUpstreams.find(
        (upstream) => upstream.value === upstreamId,
      );
      this.$emit('select', upstreamId);
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    block
    toggle-id="upstream-select"
    :toggle-text="selectedUpstreamName"
    :items="linkableUpstreams"
    infinite-scroll
    searchable
    :searching="isSearching"
    :selected="selectedUpstreamId"
    :no-results-text="__('No matching results')"
    :infinite-scroll-loading="isLoadingMore"
    @select="handleSelect"
    @search="searchUpstream"
    @bottom-reached="fetchNextPage"
  >
    <template #list-item="{ item }">
      <div class="gl-whitespace-nowrap">{{ item.text }}</div>
      <div class="gl-text-subtle">{{ item.secondaryText }}</div>
    </template>
  </gl-collapsible-listbox>
</template>
