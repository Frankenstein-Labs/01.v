<script>
import { GlKeysetPagination } from '@gitlab/ui';
import GeoReplicableItem from './geo_replicable_item.vue';

export default {
  name: 'GeoReplicable',
  components: {
    GlKeysetPagination,
    GeoReplicableItem,
  },
  props: {
    replicableItems: {
      type: Array,
      required: true,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
  },
  emits: ['action-clicked', 'next', 'prev'],
  methods: {
    handleNextPage(item) {
      this.$emit('next', item);
    },
    handlePrevPage(item) {
      this.$emit('prev', item);
    },
    handleActionClicked(data) {
      this.$emit('action-clicked', data);
    },
  },
};
</script>

<template>
  <section>
    <geo-replicable-item
      v-for="item in replicableItems"
      :key="item.id"
      :registry-id="item.id"
      :model-record-id="item.modelRecordId"
      :sync-status="item.state"
      :verification-state="item.verificationState"
      :last-synced="item.lastSyncedAt"
      :last-verified="item.verifiedAt"
      :last-sync-failure="item.lastSyncFailure"
      :verification-failure="item.verificationFailure"
      @action-clicked="handleActionClicked"
    />
    <div class="gl-mt-6 gl-flex gl-justify-center">
      <gl-keyset-pagination v-bind="pageInfo" @next="handleNextPage" @prev="handlePrevPage" />
    </div>
  </section>
</template>
