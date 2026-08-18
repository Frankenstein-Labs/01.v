<script>
import { isSubGroup } from '../utils';
import GroupToolCoverageIndicator from './group_tool_coverage_indicator.vue';
import ProjectToolCoverageIndicator from './project_tool_coverage_indicator.vue';

export default {
  components: {
    GroupToolCoverageIndicator,
    ProjectToolCoverageIndicator,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
  },
  methods: {
    isSubGroup,
  },
};
</script>

<template>
  <div id="tool-coverage" class="gl-cursor-pointer">
    <group-tool-coverage-indicator v-if="isSubGroup(item)" :item="item" />
    <project-tool-coverage-indicator v-else :item="item" />
  </div>
</template>
