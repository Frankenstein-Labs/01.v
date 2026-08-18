<script>
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import GEO_EMPTY_STATE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-geo-md.svg?url';
import { __ } from '~/locale';

export default {
  name: 'GeoListEmptyState',
  components: {
    GlEmptyState,
    GlSprintf,
    GlLink,
  },
  props: {
    emptyState: {
      type: Object,
      required: true,
    },
  },
  computed: {
    title() {
      return this.emptyState.hasFilters ? __('No results found') : this.emptyState.title;
    },
    description() {
      return this.emptyState.hasFilters
        ? __('Edit your search filter and try again.')
        : this.emptyState.description;
    },
  },
  SVG_PATH: GEO_EMPTY_STATE_SVG,
};
</script>

<template>
  <gl-empty-state :title="title" :svg-path="$options.SVG_PATH">
    <template #description>
      <gl-sprintf :message="description">
        <template #itemTitle>
          <span>{{ emptyState.itemTitle }}</span>
        </template>
        <template #link="{ content }">
          <gl-link :href="emptyState.helpLink" target="_blank">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </template>
  </gl-empty-state>
</template>
