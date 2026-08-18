<script>
import { isEmpty } from 'lodash-es';
import { TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS, PIPELINE_SOURCE_OPTIONS } from '../constants';
import RuleMultiSelect from '../../rule_multi_select.vue';

export default {
  name: 'PipelineSourceSelector',
  components: {
    RuleMultiSelect,
  },
  props: {
    pipelineSources: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    showAllSources: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['remove', 'select'],
  computed: {
    sources() {
      return Object.keys(this.items);
    },
    items() {
      return this.showAllSources
        ? PIPELINE_SOURCE_OPTIONS
        : TARGETS_BRANCHES_PIPELINE_SOURCE_OPTIONS;
    },
    selectedSources() {
      // Not including pipelineSources is the same as selecting all
      if (isEmpty(this.pipelineSources)) {
        return this.sources;
      }

      // Return empty array if 'including' is null, which means none is selected
      return this.pipelineSources.including ?? [];
    },
  },
  methods: {
    setPipelineSources(values) {
      // Early return for "select all" case
      if (values.length === Object.keys(PIPELINE_SOURCE_OPTIONS).length) {
        this.$emit('remove');
        return;
      }

      // Emit selection with null for empty arrays, otherwise use the values
      const including = values.length ? values : null;
      this.$emit('select', { pipeline_sources: { including } });
    },
  },
};
</script>

<template>
  <rule-multi-select
    class="!gl-inline gl-align-middle"
    data-testid="pipeline-source"
    :item-type-name="s__('SecurityOrchestration|pipeline sources')"
    :items="items"
    :value="selectedSources"
    @input="setPipelineSources"
  />
</template>
