<script>
import BoardView from '~/work_items/board/board_view.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'BoardViewEE',
  components: {
    BoardView,
  },
  mixins: [glListenersMixin],
  props: {
    rootPageFullPath: {
      type: String,
      required: true,
    },
    queryVariables: {
      type: Object,
      required: true,
    },
    collapsedGroups: {
      type: Array,
      required: false,
      default: () => [],
    },
    groupOrder: {
      type: Array,
      required: false,
      default: () => [],
    },
    canReorder: {
      type: Boolean,
      required: false,
      default: false,
    },
    hiddenMetadataKeys: {
      type: Array,
      required: false,
      default: () => [],
    },
    activeItem: {
      type: Object,
      required: false,
      default: null,
    },
    detailPanelEnabled: {
      type: Boolean,
      required: false,
      default: true,
    },
    updatedWorkItem: {
      type: Object,
      required: false,
      default: null,
    },
    preselectedWorkItemType: {
      type: String,
      required: false,
      default: null,
    },
    canCreateWorkItem: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
};
</script>

<template>
  <board-view
    :root-page-full-path="rootPageFullPath"
    :query-variables="queryVariables"
    :collapsed-groups="collapsedGroups"
    :group-order="groupOrder"
    :can-reorder="canReorder"
    :hidden-metadata-keys="hiddenMetadataKeys"
    :active-item="activeItem"
    :detail-panel-enabled="detailPanelEnabled"
    :updated-work-item="updatedWorkItem"
    :preselected-work-item-type="preselectedWorkItemType"
    :can-create-work-item="canCreateWorkItem"
    v-on="glListeners()"
  />
</template>
