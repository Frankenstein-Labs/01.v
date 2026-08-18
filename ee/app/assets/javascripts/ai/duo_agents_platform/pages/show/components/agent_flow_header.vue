<script>
import { GlSkeletonLoader } from '@gitlab/ui';
import { formatAgentFlowTitleWithId } from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'AgentFlowHeader',
  components: {
    GlSkeletonLoader,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    title: {
      required: true,
      type: String,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
  },

  computed: {
    pageTitle() {
      return formatAgentFlowTitleWithId(
        this.title,
        this.agentFlowDefinition,
        this.$route.params.id,
      );
    },
  },
};
</script>
<template>
  <div class="gl-mt-6">
    <div v-if="isLoading">
      <gl-skeleton-loader :lines="1" :width="400" />
    </div>
    <div v-else class="gl-flex gl-items-center gl-gap-2">
      <h1 class="gl-heading-1 gl-m-0">{{ pageTitle }}</h1>
    </div>
  </div>
</template>
