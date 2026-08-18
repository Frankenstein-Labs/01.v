<script>
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import { REF_TYPE_BRANCHES } from '~/vue_shared/components/ref/constants';

export default {
  name: 'MergeTrainBranchSelector',
  ENABLED_REF_TYPES: [REF_TYPE_BRANCHES],
  components: {
    RefSelector,
  },
  inject: {
    projectId: {
      default: '',
    },
  },
  props: {
    selectedBranch: {
      type: String,
      required: true,
    },
  },
  emits: ['branch-changed'],
  data() {
    return {
      branch: this.selectedBranch,
    };
  },
};
</script>

<template>
  <div class="gl-mt-3 gl-flex gl-items-center">
    <span class="gl-mr-3">{{ s__('Pipelines|Filter by target branch') }}</span>
    <ref-selector
      :value="branch"
      :project-id="projectId"
      :enabled-ref-types="$options.ENABLED_REF_TYPES"
      @input="$emit('branch-changed', $event)"
    />
  </div>
</template>
