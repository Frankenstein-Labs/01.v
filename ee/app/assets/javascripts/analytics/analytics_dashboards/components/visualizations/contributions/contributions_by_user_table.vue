<script>
import GroupMembersTable from 'ee/analytics/contribution_analytics/components/group_members_table.vue';

export default {
  name: 'ContributionsByUserTable',
  components: {
    GroupMembersTable,
  },
  props: {
    data: {
      type: Array,
      required: true,
    },
  },
};
</script>
<template>
  <group-members-table :contributions="data" />
</template>
