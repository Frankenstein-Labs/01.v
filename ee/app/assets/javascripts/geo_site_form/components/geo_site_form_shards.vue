<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__, n__ } from '~/locale';
import { SELECTIVE_SYNC_SHARDS } from '../constants';

const mapItemToListboxFormat = (item) => ({ ...item, text: item.label });

export default {
  name: 'GeoSiteFormShards',
  i18n: {
    noSelectedDropdownTitle: s__('Geo|Select shards to replicate'),
    withSelectedDropdownTitle: (len) => n__('Geo|%d shard selected', 'Geo|%d shards selected', len),
    nothingFound: s__('Geo|Nothing found…'),
  },
  components: {
    GlCollapsibleListbox,
  },
  props: {
    syncShardsOptions: {
      type: Array,
      required: true,
    },
    selectedShards: {
      type: Array,
      required: true,
    },
  },
  emits: ['update-sync-options'],
  computed: {
    dropdownItems() {
      return this.syncShardsOptions?.map(mapItemToListboxFormat) || [];
    },
    dropdownTitle() {
      if (this.selectedShards.length === 0) {
        return this.$options.i18n.noSelectedDropdownTitle;
      }

      return this.$options.i18n.withSelectedDropdownTitle(this.selectedShards.length);
    },
  },
  methods: {
    onItemSelect(items) {
      this.$emit('update-sync-options', { key: SELECTIVE_SYNC_SHARDS, value: items });
    },
  },
};
</script>

<template>
  <gl-collapsible-listbox
    :items="dropdownItems"
    :toggle-text="dropdownTitle"
    :selected="selectedShards"
    :no-results-text="$options.i18n.nothingFound"
    multiple
    fluid-width
    @select="onItemSelect"
  />
</template>
