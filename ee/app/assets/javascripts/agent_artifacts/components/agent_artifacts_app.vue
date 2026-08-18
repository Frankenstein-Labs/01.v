<script>
import AgentArtifactsTable from './agent_artifacts_table.vue';
import AgentArtifactsFilteredSearch from './agent_artifacts_filtered_search.vue';
import SessionDetailsDrawer from './session_details_drawer.vue';

export default {
  name: 'AgentArtifactsApp',
  components: {
    AgentArtifactsTable,
    AgentArtifactsFilteredSearch,
    SessionDetailsDrawer,
  },
  data() {
    return {
      activeItem: null,
      filter: {},
      selectedEvent: null,
    };
  },
  methods: {
    handleRowClick(item) {
      this.activeItem = item;
      this.selectedEvent = null;
    },
    handleFilter(filter) {
      this.activeItem = null;
      this.selectedEvent = null;
      this.filter = filter;
    },
    handleDrawerClose() {
      this.activeItem = null;
      this.selectedEvent = null;
    },
  },
};
</script>
<template>
  <div>
    <agent-artifacts-filtered-search class="gl-mt-5" @filter="handleFilter" />

    <agent-artifacts-table
      class="gl-mt-5"
      :active-item="activeItem"
      :filter="filter"
      @row-click="handleRowClick"
    />

    <session-details-drawer
      v-if="activeItem"
      :active-item="activeItem"
      :selected-event="selectedEvent"
      @close="handleDrawerClose"
      @select="selectedEvent = $event"
      @back="selectedEvent = null"
    />
  </div>
</template>
