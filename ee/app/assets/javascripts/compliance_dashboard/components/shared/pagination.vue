<script>
import { GlKeysetPagination } from '@gitlab/ui';
import PageSizeSelector from '~/vue_shared/components/page_size_selector.vue';
import { setUrlParams } from '~/lib/utils/url_utility';

export default {
  name: 'ComplianceSharedPagination',
  components: {
    GlKeysetPagination,
    PageSizeSelector,
  },
  props: {
    pageInfo: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    perPage: {
      type: Number,
      required: true,
    },
  },
  emits: ['next', 'page-size-change', 'prev'],
  computed: {
    previousLink() {
      return setUrlParams(
        { before: this.pageInfo.startCursor, after: null },
        { url: window.location.href },
      );
    },
    nextLink() {
      return setUrlParams(
        { before: null, after: this.pageInfo.endCursor },
        { url: window.location.href },
      );
    },
  },
  methods: {
    loadPrevPage(previousCursor) {
      this.$emit('prev', previousCursor);
    },
    loadNextPage(nextCursor) {
      this.$emit('next', nextCursor);
    },
    onPageSizeChange(size) {
      this.$emit('page-size-change', size);
    },
    onPaginationClick(event) {
      // this check here is to ensure the proper default behaviour when a user ctrl/cmd + clicks the link
      if (event.shiftKey || event.ctrlKey || event.altKey || event.metaKey) {
        return;
      }
      event.preventDefault();
    },
  },
};
</script>

<template>
  <div v-if="pageInfo" class="gl-flex gl-items-center gl-justify-between">
    <div class="gl-hidden gl-grow gl-basis-0 @md/panel:gl-block"></div>
    <div class="gl-flex gl-grow gl-basis-0 gl-justify-center">
      <gl-keyset-pagination
        v-bind="pageInfo"
        :disabled="isLoading"
        :prev-button-link="previousLink"
        :next-button-link="nextLink"
        @prev="loadPrevPage"
        @next="loadNextPage"
        @click="onPaginationClick"
      />
    </div>
    <div class="gl-flex gl-grow gl-basis-0 gl-justify-end">
      <page-size-selector :value="perPage" @input="onPageSizeChange" />
    </div>
  </div>
</template>
