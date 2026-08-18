<script>
import { GlKeysetPagination } from '@gitlab/ui';

export default {
  name: 'WorkspacesListPagination',
  components: {
    GlKeysetPagination,
  },
  props: {
    pageInfo: {
      type: Object,
      required: true,
    },
    pageSize: {
      type: Number,
      required: true,
    },
  },
  emits: ['input'],
  methods: {
    nextPage() {
      this.$emit('input', {
        after: this.pageInfo.endCursor,
        first: this.pageSize,
      });
    },
    previousPage() {
      this.$emit('input', {
        before: this.pageInfo.startCursor,
        first: this.pageSize,
      });
    },
  },
};
</script>
<template>
  <div
    v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage"
    class="gl-mt-3 gl-flex gl-justify-center"
  >
    <gl-keyset-pagination
      :has-next-page="pageInfo.hasNextPage"
      :has-previous-page="pageInfo.hasPreviousPage"
      @prev="previousPage"
      @next="nextPage"
    />
  </div>
</template>
