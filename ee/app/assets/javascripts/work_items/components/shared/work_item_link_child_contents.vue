<script>
import { GlTooltipDirective } from '@gitlab/ui';
import WorkItemLinkChildContents from '~/work_items/components/shared/work_item_link_child_contents.vue';
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';
import { WIDGET_TYPE_STATUS, METADATA_KEYS } from '~/work_items/constants';
import { getMetadataWidgetsFromWorkItem } from '~/work_items/utils';

export default {
  name: 'WorkItemLinkChildContentsEE',
  components: {
    WorkItemLinkChildContents,
    WorkItemStatusBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    childItem: {
      type: Object,
      required: true,
    },
    canUpdate: {
      type: Boolean,
      required: true,
    },
    isGroup: {
      type: Boolean,
      required: false,
      default: false,
    },
    workItemFullPath: {
      type: String,
      required: true,
    },
    hiddenMetadataKeys: {
      type: Array,
      required: false,
      default: () => [],
    },
    contextualViewEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['click', 'mouseout', 'mouseover', 'remove-child'],
  computed: {
    metadataWidgets() {
      return getMetadataWidgetsFromWorkItem(this.childItem);
    },
    customStatus() {
      return this.metadataWidgets[WIDGET_TYPE_STATUS]?.status;
    },
    showCustomStatus() {
      return this.customStatus && !this.hiddenMetadataKeys.includes(METADATA_KEYS.STATUS);
    },
  },
};
</script>

<template>
  <work-item-link-child-contents
    :child-item="childItem"
    :can-update="canUpdate"
    :is-group="isGroup"
    :hidden-metadata-keys="hiddenMetadataKeys"
    :work-item-full-path="workItemFullPath"
    :contextual-view-enabled="contextualViewEnabled"
    @mouseover="$emit('mouseover')"
    @mouseout="$emit('mouseout')"
    @click="$emit('click', $event)"
    @remove-child="$emit('remove-child', childItem)"
  >
    <template #child-contents>
      <div class="gl-max-w-20">
        <work-item-status-badge v-if="showCustomStatus" :item="customStatus" />
      </div>
    </template>
  </work-item-link-child-contents>
</template>
