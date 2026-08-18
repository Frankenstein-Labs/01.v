<script>
import WorkItemStatusBadge from 'ee/work_items/components/shared/work_item_status_badge.vue';

export default {
  name: 'StatusPresenterEE',
  components: {
    WorkItemStatusBadge,
  },
  props: {
    data: {
      required: true,
      type: Object,
    },
  },
};
</script>
<template>
  <work-item-status-badge :item="data" />
</template>
