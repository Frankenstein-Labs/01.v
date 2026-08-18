<script>
import { GlEmptyState, GlKeysetPagination } from '@gitlab/ui';
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg';
import EmptyResult from '~/vue_shared/components/empty_result.vue';
import { AGENTS_PLATFORM_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import AgentFlowListItem from './agent_flow_list_item.vue';

export default {
  name: 'AgentFlowList',
  components: {
    EmptyResult,
    GlEmptyState,
    GlKeysetPagination,
    AgentFlowListItem,
  },
  props: {
    showEmptyState: {
      required: true,
      type: Boolean,
    },
    showProjectInfo: {
      required: false,
      type: Boolean,
      default: false,
    },
    workflows: {
      required: true,
      type: Array,
    },
    workflowsPageInfo: {
      required: true,
      type: Object,
    },
  },
  emits: ['next-page', 'prev-page'],
  computed: {
    hasWorkflows() {
      return this.workflows?.length > 0;
    },
    displayPagination() {
      return this.workflowsPageInfo?.hasNextPage || this.workflowsPageInfo?.hasPreviousPage;
    },
  },
  showRoute: AGENTS_PLATFORM_SHOW_ROUTE,
  emptyStateIllustrationPath,
};
</script>
<template>
  <div :class="{ 'gl-self-center': !hasWorkflows }" class="gl-w-full">
    <gl-empty-state
      v-if="showEmptyState"
      :title="s__('DuoAgentsPlatform|No agent sessions yet')"
      :description="s__('DuoAgentsPlatform|New agent sessions will appear here.')"
      :svg-path="$options.emptyStateIllustrationPath"
    />
    <template v-else>
      <ul
        v-if="hasWorkflows"
        class="gl-divide-x-0 gl-divide-y-1 gl-divide-solid gl-divide-subtle gl-px-0"
      >
        <agent-flow-list-item
          v-for="item in workflows"
          :key="item.id"
          :item="item"
          :show-project-info="showProjectInfo"
        />
      </ul>
      <empty-result v-else type="search" />
      <gl-keyset-pagination
        v-if="displayPagination"
        v-bind="workflowsPageInfo"
        class="gl-mt-5 gl-flex gl-justify-center gl-pb-4"
        @prev="$emit('prev-page')"
        @next="$emit('next-page')"
      />
    </template>
  </div>
</template>
